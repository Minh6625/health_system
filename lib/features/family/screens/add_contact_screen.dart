import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shared_family_mock_provider.dart';
import '../widgets/add_contact_intro_card.dart';
import '../widgets/mode_segmented_control.dart';
import '../widgets/my_code_hero_card.dart';
import '../widgets/qr_scanner_viewport.dart';
import '../widgets/scanned_user_confirm_sheet.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  AddContactMode _currentMode = AddContactMode.scan;

  void _onModeChanged(AddContactMode mode) {
    setState(() {
      _currentMode = mode;
    });
  }

  void _simulateScanSuccess() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScannedUserConfirmSheet(
        onConfirm: (tags, email) async {
          Navigator.pop(context); // close sheet

          await context.read<SharedFamilyMockProvider>().sendRequest(email, tags);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã gửi lời mời thành công!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context); // Return to contact list
          }
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _simulateScanError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mã QR không hợp lệ hoặc đã hết hạn.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _onShareMyCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mở native share sheet (mock)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB), // bg.primary
      appBar: AppBar(
        title: const Text('Thêm liên hệ', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF12304A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AddContactIntroCard(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ModeSegmentedControl(
              currentMode: _currentMode,
              onModeChanged: _onModeChanged,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _currentMode == AddContactMode.scan
                  ? Padding(
                      key: const ValueKey('scan_mode'),
                      padding: const EdgeInsets.all(16),
                      child: QRScannerViewport(
                        onSimulateScanSuccess: _simulateScanSuccess,
                        onSimulateScanError: _simulateScanError,
                      ),
                    )
                  : Padding(
                      key: const ValueKey('my_code_mode'),
                      padding: const EdgeInsets.all(16),
                      child: MyCodeHeroCard(
                        pinCode: '482 931',
                        expiryText: '23:59 hôm nay',
                        onShare: _onShareMyCode,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
