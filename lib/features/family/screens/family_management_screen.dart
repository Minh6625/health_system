import 'package:healthguard/features/family/screens/search_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:healthguard/features/family/screens/user_detail_screen.dart';
import 'package:healthguard/features/family/models/relationship.dart';
import 'package:healthguard/features/family/providers/target_profile_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<ProfileProvider>().profile == null) {
        context.read<ProfileProvider>().fetchProfile();
      }
      context.read<TargetProfileProvider>().fetchProfiles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TargetProfileProvider, ProfileProvider>(
      builder: (context, targetProvider, profileProvider, _) {
        final myId = profileProvider.profile?.userId;

        final accepted = targetProvider.relationships
            .where((r) => r.status == 'accepted')
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Quản lý Gia đình'),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.person_search), text: 'Tìm kiếm'),
                Tab(icon: Icon(Icons.people), text: 'Người thân'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              UserSearchTab(
                onSwitchTab: () {
                  _tabController.animateTo(1);
                },
              ),
              targetProvider.isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 16,
                                        width: double.infinity,
                                        color: Colors.grey,
                                        margin: const EdgeInsets.only(bottom: 8),
                                      ),
                                      Container(
                                        height: 14,
                                        width: 150,
                                        color: Colors.grey,
                                        margin: const EdgeInsets.only(bottom: 8),
                                      ),
                                      Container(
                                        height: 12,
                                        width: 100,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 1200.ms, color: Colors.white60);
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () => targetProvider.fetchProfiles(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'Bệnh nhân / Người thân',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (accepted.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Chưa có dữ liệu nào. Hãy tìm kiếm và liên kết!',
                              ),
                            )
                          else
                            ...accepted.map(
                              (r) =>
                                  _buildAcceptedItem(r, myId, targetProvider),
                            ),
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcceptedItem(
    Relationship relationship,
    int? myId,
    TargetProfileProvider provider,
  ) {
    final bool amICaregiver = relationship.caregiverId == myId;
    final otherName = amICaregiver
        ? relationship.patientName
        : relationship.caregiverName;
    final otherEmail = amICaregiver
        ? relationship.patientEmail
        : relationship.caregiverEmail;
    final description = amICaregiver
        ? 'Bạn đang xem sức khỏe'
        : 'Đang xem sức khỏe của bạn';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserDetailScreen(
              userId: amICaregiver
                  ? relationship.patientId
                  : relationship.caregiverId,
              name: otherName,
              email: otherEmail,
              phone: null,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      otherEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: amICaregiver ? Colors.teal : Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
