import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
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
        context.read<SharedFamilyMockProvider>().loadInitialData(
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
      await context.read<SharedFamilyMockProvider>().loadInitialData(
        auth.currentUser!.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Consumer<SharedFamilyMockProvider>(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                if (provider.error != null && provider.contacts.isNotEmpty)
                  _buildOfflineBanner(provider.error!),
                LinkedContactsHeroCard(
                  totalContacts: provider.acceptedContacts.length,
                  pendingCount: provider.pendingRequests.length,
                  onAddPressed: _navigateToAddContact,
                ),
                const SizedBox(height: 16),
                if (provider.contacts.isEmpty)
                  LinkedContactsEmptyState(onAddPressed: _navigateToAddContact)
                else ...[
                  if (provider.pendingRequests.isNotEmpty) ...[
                    PendingRequestsSection(requests: provider.pendingRequests),
                    const SizedBox(height: 24),
                  ],
                  if (provider.acceptedContacts.isNotEmpty)
                    GroupedContactsSection(contacts: provider.acceptedContacts),
                ],
                const SizedBox(height: 48), // Bottom Safe Spacer
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(SharedFamilyMockProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contact_mail_outlined,
              size: 68,
              color: Colors.teal.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: Colors.amber.shade900)),
          ),
        ],
      ),
    );
  }
}
