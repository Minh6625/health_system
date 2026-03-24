import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/add_contact_intro_card.dart';
import '../widgets/mode_segmented_control.dart';
import '../widgets/my_code_hero_card.dart';
import '../widgets/qr_scanner_viewport.dart';
import '../widgets/scanned_user_confirm_sheet.dart';
import '../widgets/search_phone_view.dart';
import '../repositories/family_repository.dart';
import '../models/user_search_model.dart';
import '../providers/shared_family_mock_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  AddContactMode _currentMode = AddContactMode.scan;
  final FamilyRepository _repository = FamilyRepository();

  void _onModeChanged(AddContactMode mode) {
    setState(() {
      _currentMode = mode;
    });
  }

  Future<bool> _simulateScanSuccess(
    UserSearchModel? user, {
    bool isCancel = false,
    bool isUnlink = false,
    bool isAccept = false,
    bool isReject = false,
  }) async {
    bool success = false;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScannedUserConfirmSheet(
        fromPhoneSearch: user != null,
        userName: user?.fullName,
        avatarUrl: user?.avatarUrl,
        isCancel: isCancel,
        isUnlink: isUnlink,
        isAccept: isAccept,
        isReject: isReject,
        onConfirm: (tags, email) async {
          try {
            if (isUnlink || isReject) {
              if (user != null && user.relationshipId != null) {
                await _repository.removeRelationshipById(user.relationshipId!);
              }
              if (mounted) {
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  context.read<SharedFamilyMockProvider>().loadInitialData(
                    auth.currentUser!.userId,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isReject
                          ? 'Đã từ chối yêu cầu thành công!'
                          : 'Đã hủy liên kết thành công!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            } else if (isAccept) {
              if (user != null && user.relationshipId != null) {
                await _repository.acceptRelationship(user.relationshipId!);
              }
              if (mounted) {
                final auth = context.read<AuthProvider>();
                if (auth.currentUser != null) {
                  context.read<SharedFamilyMockProvider>().loadInitialData(
                    auth.currentUser!.userId,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xác nhận yêu cầu thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            } else if (isCancel) {
              if (user != null) {
                await _repository.cancelConnectionRequest(user.id);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã hủy lời mời thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            } else {
              if (user != null) {
                await _repository.sendConnectionRequest(targetUserId: user.id);
              } else {
                // Simulated QR code fallback
                await _repository.sendConnectionRequest(
                  targetUserId: 1,
                ); // Mock dummy ID
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi lời mời thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            }
            if (mounted) Navigator.pop(context, true);
          } catch (e) {
            String errorMsg = e.toString().replaceAll('Exception: ', '').trim();
            bool isAlreadySent =
                errorMsg.contains('Mối quan hệ đã tồn tại') ||
                errorMsg.contains('đang chờ xác nhận');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAlreadySent ? 'Lời mời đã được gửi trước đó!' : errorMsg,
                  ),
                  backgroundColor: isAlreadySent ? Colors.orange : Colors.red,
                ),
              );
            }
            if (isAlreadySent) {
              success = true;
              if (mounted) Navigator.pop(context, true);
            }
          }
        },
        onCancel: () {
          Navigator.pop(context, false);
        },
      ),
    );

    if (success && user == null && mounted) {
      Navigator.pop(context); // Return to contact list if scanned (mock)
    }

    return success;
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
      const SnackBar(content: Text('Mở native share sheet (mock)')),
    );
  }

  Widget _buildCurrentModeView() {
    switch (_currentMode) {
      case AddContactMode.scan:
        return Padding(
          key: const ValueKey('scan_mode'),
          padding: const EdgeInsets.all(16),
          child: QRScannerViewport(
            onSimulateScanSuccess: () => _simulateScanSuccess(null),
            onSimulateScanError: _simulateScanError,
          ),
        );
      case AddContactMode.myCode:
        return Padding(
          key: const ValueKey('my_code_mode'),
          padding: const EdgeInsets.all(16),
          child: MyCodeHeroCard(
            pinCode: '482 931',
            expiryText: '23:59 hôm nay',
            onShare: _onShareMyCode,
          ),
        );
      case AddContactMode.searchPhone:
        return Padding(
          key: const ValueKey('search_phone_mode'),
          padding: const EdgeInsets.all(16),
          child: SearchPhoneView(onConnect: _simulateScanSuccess),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB), // bg.primary
      appBar: AppBar(
        title: const Text(
          'Thêm liên hệ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              child: _buildCurrentModeView(),
            ),
          ),
        ],
      ),
    );
  }
}
