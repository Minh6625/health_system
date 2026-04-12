import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_connect_provider.dart';
import 'package:healthguard/features/device/widgets/device_connect/method_select_step.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_qr_scan_step.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_manual_code_step.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_identity_confirm_card.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_connect_success_card.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_connect_error_card.dart';

class DeviceConnectScreen extends StatelessWidget {
  const DeviceConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceConnectProvider(),
      child: const _DeviceConnectContent(),
    );
  }
}

class _DeviceConnectContent extends StatelessWidget {
  const _DeviceConnectContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Kết nối thiết bị', style: AppTextStyles.sectionTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: Consumer<DeviceConnectProvider>(
          builder: (context, provider, _) {
            // Disable back button while verifying or pairing
            final canPop = provider.state != DeviceConnectState.pairing &&
                           provider.state != DeviceConnectState.verifying &&
                           provider.state != DeviceConnectState.success;
            
            return IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: canPop
                  ? () {
                      if (provider.state != DeviceConnectState.intro) {
                        provider.backToIntro();
                      } else {
                        Navigator.of(context).pop();
                      }
                    }
                  : null,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Consumer<DeviceConnectProvider>(
          builder: (context, provider, child) {
            // Handle automatic navigation back on success
            if (provider.state == DeviceConnectState.success) {
              Future.delayed(const Duration(milliseconds: 2000), () {
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context, true); // Return true to trigger refetch
                }
              });
            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                
                final state = provider.state;
                if (state == DeviceConnectState.pairing ||
                    state == DeviceConnectState.verifying ||
                    state == DeviceConnectState.success) {
                  return; // Prevent back navigation midway
                }
                
                if (state != DeviceConnectState.intro) {
                  provider.backToIntro();
                  return; // Go back to method select first
                }
                Navigator.of(context).pop();
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildCurrentState(provider.state),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentState(DeviceConnectState state) {
    switch (state) {
      case DeviceConnectState.intro:
        return SingleChildScrollView(key: const ValueKey('intro'), child: const MethodSelectStep());
      case DeviceConnectState.scanning:
        return SingleChildScrollView(key: const ValueKey('scan'), child: const DeviceQrScanStep());
      case DeviceConnectState.manualForm:
        // Manual form also acts as verifying screen when isVerifying is true
      case DeviceConnectState.verifying:
        return SingleChildScrollView(key: const ValueKey('manual'), child: const DeviceManualCodeStep());
      case DeviceConnectState.confirmIdentity:
      case DeviceConnectState.pairing:
        return SingleChildScrollView(key: const ValueKey('confirm'), child: const DeviceIdentityConfirmCard());
      case DeviceConnectState.success:
        return Center(key: const ValueKey('success'), child: const DeviceConnectSuccessCard());
      case DeviceConnectState.error:
        return Center(key: const ValueKey('error'), child: const DeviceConnectErrorCard());
    }
  }
}
