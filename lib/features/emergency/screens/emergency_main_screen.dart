import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:healthguard/features/emergency/screens/warning_screen.dart';

class EmergencyMainScreen extends StatefulWidget {
  const EmergencyMainScreen({super.key});

  @override
  State<EmergencyMainScreen> createState() => _EmergencyMainScreenState();
}

class _EmergencyMainScreenState extends State<EmergencyMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text(
            'Khẩn cấp',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.black54,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: Colors.blue.shade700, width: 3.0),
                insets: const EdgeInsets.symmetric(horizontal: 24.0),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'SOS'),
                Tab(text: 'Danh sách SOS'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [WarningScreen(), EmergencySOSReceivedListScreen()],
      ),
    );
  }
}
