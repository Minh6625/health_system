import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/target_profile_provider.dart';

class ProfileSwitcher extends StatefulWidget {
  final VoidProfileCallback? onProfileChanged;

  const ProfileSwitcher({Key? key, this.onProfileChanged}) : super(key: key);

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

typedef VoidProfileCallback = void Function();

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TargetProfileProvider>().fetchProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TargetProfileProvider>(
      builder: (context, provider, child) {
        final acceptedProfiles = provider.profiles;

        // Default item for "Bản thân" (Own profile)
        final List<DropdownMenuItem<int?>> items = [
          const DropdownMenuItem<int?>(value: null, child: Text('Cá nhân')),
        ];

        for (var p in acceptedProfiles) {
          if (p.relationshipType == 'self') continue;
          items.add(
            DropdownMenuItem<int?>(
              value: p.id,
              child: Text(
                p.fullName.isNotEmpty ? p.fullName : 'User \${p.id}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: provider.targetProfileId,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              dropdownColor: Colors.teal.shade700,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              items: items,
              onChanged: (int? newValue) {
                if (provider.targetProfileId != newValue) {
                  provider.setTargetProfile(newValue);
                  if (widget.onProfileChanged != null) {
                    widget.onProfileChanged!();
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
