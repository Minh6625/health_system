import 'package:flutter/material.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/family/providers/family_relationship_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';
import '../widgets/linked_contacts_hero_card.dart';
import '../widgets/pending_requests_section.dart';
import '../widgets/grouped_contacts_section.dart';
import '../widgets/linked_contacts_empty_state.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<FamilyRelationshipProvider>().loadInitialData(
          auth.currentUser!.userId,
        );
      }
    });
  }

  Future<void> _navigateToAddContact() async {
    await Navigator.pushNamed(context, '/add-contact');
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      await context.read<FamilyRelationshipProvider>().loadInitialData(
        auth.currentUser!.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Consumer<FamilyRelationshipProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.contacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.contacts.isEmpty) {
            return _buildErrorState(provider);
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth = context.read<AuthProvider>();
              if (auth.currentUser != null) {
                await provider.loadInitialData(auth.currentUser!.userId);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.gapLg, vertical: AppSpacing.gapLg),
              children: [
                if (provider.error != null && provider.contacts.isNotEmpty)
                  _buildOfflineBanner(provider.error!),
                LinkedContactsHeroCard(
                  totalContacts: provider.acceptedContacts.length,
                  pendingCount: provider.pendingRequests.length,
                  onAddPressed: _navigateToAddContact,
                ),
                SizedBox(height: AppSpacing.gapLg),
                if (provider.contacts.isEmpty)
                  LinkedContactsEmptyState(onAddPressed: _navigateToAddContact)
                else ...[
                  if (provider.pendingRequests.isNotEmpty) ...[
                    PendingRequestsSection(requests: provider.pendingRequests),
                    SizedBox(height: AppSpacing.sectionGapXl),
                  ],
                  if (provider.acceptedContacts.isNotEmpty)
                    GroupedContactsSection(contacts: provider.acceptedContacts),
                ],
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(FamilyRelationshipProvider provider) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sectionGapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contact_mail_outlined,
              size: 68,
              color: AppColors.brandPrimaryLight,
            ),
            SizedBox(height: AppSpacing.gapLg),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.sectionGapMd),
            ElevatedButton.icon(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  provider.loadInitialData(auth.currentUser!.userId);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(String msg) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.gapLg),
      padding: EdgeInsets.all(AppSpacing.gapMd),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, color: AppColors.warning),
          SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: Text(msg, style: TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}
