import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile;
import 'package:provider/provider.dart';
import 'package:yomu/yomu.dart';
import '../widgets/add_contact_intro_card.dart';
import '../widgets/mode_segmented_control.dart';
import '../widgets/my_code_hero_card.dart';
import '../widgets/qr_scanner_viewport.dart';
import '../widgets/scanned_user_confirm_sheet.dart';
import '../widgets/search_phone_view.dart';
import '../repositories/family_repository.dart';
import '../models/contact_tag.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  String _buildMyQrPayload() {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return 'HG_ADD_CONTACT';
    }

    final email = Uri.encodeComponent(currentUser.email);
    return 'HG_ADD_CONTACT:${currentUser.userId}:$email';
  }

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
    String? statusMessage,
    bool hideActions = false,
    bool showTags = true,
    String? cancelButtonText,
    String? confirmButtonText,
  }) async {
    final rootContext = context;
    bool success = false;

    await showModalBottomSheet<bool>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ScannedUserConfirmSheet(
        fromPhoneSearch: user != null,
        userName: user?.fullName,
        avatarUrl: user?.avatarUrl,
        email: user?.email,
        phone: user?.phone,
        isCancel: isCancel,
        isUnlink: isUnlink,
        isAccept: isAccept,
        isReject: isReject,
        statusMessage: statusMessage,
        hideActions: hideActions,
        showTags: showTags,
        cancelButtonText: cancelButtonText,
        confirmButtonText: confirmButtonText,
        onConfirm: (tags, email) async {
          final selectedTags = tags.isNotEmpty
              ? tags
              : [ContactTagsConfig.defaultTags.first];

          final tagsData = selectedTags
              .map((t) => {'id': t.id, 'name': t.name})
              .toList();
          final primaryLabel = selectedTags.first.name;

          try {
            if (isUnlink || isReject) {
              if (user != null && user.relationshipId != null) {
                await _repository.removeRelationshipById(user.relationshipId!);
              }
              if (mounted) {
                final auth = rootContext.read<AuthProvider>();
                if (auth.currentUser != null) {
                  rootContext.read<SharedFamilyMockProvider>().loadInitialData(
                    auth.currentUser!.userId,
                  );
                }
                ScaffoldMessenger.of(rootContext).showSnackBar(
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
                await _repository.updateRelationship(user.relationshipId!, {
                  'tags': tagsData,
                  'primary_relationship_label': primaryLabel,
                });
              }
              if (mounted) {
                final auth = rootContext.read<AuthProvider>();
                if (auth.currentUser != null) {
                  rootContext.read<SharedFamilyMockProvider>().loadInitialData(
                    auth.currentUser!.userId,
                  );
                }
                ScaffoldMessenger.of(rootContext).showSnackBar(
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
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Đã hủy lời mời thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            } else {
              if (user != null) {
                if (user.id > 0) {
                  await _repository.sendConnectionRequest(
                    targetUserId: user.id,
                    tags: tagsData,
                    primaryLabel: primaryLabel,
                  );
                } else {
                  await _repository.sendConnectionRequest(
                    email: user.email,
                    tags: tagsData,
                    primaryLabel: primaryLabel,
                  );
                }
              } else {
                // Simulated QR code fallback
                await _repository.sendConnectionRequest(
                  targetUserId: 1, // Mock dummy ID
                  tags: tagsData,
                  primaryLabel: primaryLabel,
                );
              }

              if (mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi lời mời thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              success = true;
            }
            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
          } catch (e) {
            String errorMsg = e.toString().replaceAll('Exception: ', '').trim();
            bool isAlreadySent =
                errorMsg.contains('Mối quan hệ đã tồn tại') ||
                errorMsg.contains('đang chờ xác nhận');

            if (mounted) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
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
              if (sheetContext.mounted) Navigator.pop(sheetContext, true);
            }
          }
        },
        onCancel: () {
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext, false);
          }
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
        content: Text('Mã QR không hợp lệ.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<String?> _decodeQrFromImagePath(String imagePath) async {
    final yomuResult = await _decodeQrWithYomu(imagePath);
    if (yomuResult != null) {
      return yomuResult;
    }

    final mobileResult = await _decodeQrWithMobileScanner(imagePath);
    if (mobileResult != null) {
      return mobileResult;
    }

    return _decodeQrWithMlKit(imagePath);
  }

  Future<String?> _decodeQrWithYomu(String imagePath) async {
    try {
      final bytes = await XFile(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return null;
      }

      final rgbaImage = decodedImage.convert(numChannels: 4);
      final rgbaBytes = rgbaImage.getBytes(order: img.ChannelOrder.rgba);

      final yomuImage = YomuImage.rgba(
        bytes: rgbaBytes,
        width: rgbaImage.width,
        height: rgbaImage.height,
      );

      final result = Yomu.qrOnly.decode(yomuImage);
      final raw = result.text.trim();
      if (raw.isNotEmpty) {
        return raw;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _decodeQrWithMobileScanner(String imagePath) async {
    final controller = mobile.MobileScannerController(
      formats: const [mobile.BarcodeFormat.qrCode],
      detectionSpeed: mobile.DetectionSpeed.noDuplicates,
    );

    try {
      final capture = await controller.analyzeImage(imagePath);
      if (capture == null || capture.barcodes.isEmpty) {
        return null;
      }

      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue?.trim();
        if (raw != null && raw.isNotEmpty) {
          return raw;
        }
      }
      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _decodeQrWithMlKit(String imagePath) async {
    final scanner = mlkit.BarcodeScanner(formats: [mlkit.BarcodeFormat.qrCode]);

    try {
      final input = mlkit.InputImage.fromFilePath(imagePath);
      final barcodes = await scanner.processImage(input);

      if (barcodes.isEmpty) {
        return null;
      }

      for (final code in barcodes) {
        final raw = code.rawValue?.trim();
        if (raw != null && raw.isNotEmpty) {
          return raw;
        }
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      await scanner.close();
    }
  }

  Map<String, dynamic>? _parseAddContactQrPayload(String rawValue) {
    final base = rawValue
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim();

    if (base.isEmpty) {
      return null;
    }

    final candidates = <String>{base};
    try {
      final decoded = Uri.decodeComponent(base).trim();
      if (decoded.isNotEmpty) {
        candidates.add(decoded);
      }
    } catch (_) {}

    for (final trimmed in candidates) {
      final parsed = _parseSingleQrCandidate(trimmed);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  Map<String, dynamic>? _parseSingleQrCandidate(String trimmed) {
    if (trimmed.startsWith('HG_ADD_CONTACT:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final userId = int.tryParse(parts[1]);
        final email = parts.length >= 3
            ? Uri.decodeComponent(parts[2]).trim()
            : null;
        if (userId != null && userId > 0) {
          return {
            'type': 'add_contact',
            'user_id': userId,
            if (email != null && email.isNotEmpty) 'email': email,
          };
        }
      }
    }

    if (trimmed.startsWith('HG_USER:')) {
      final userId = int.tryParse(trimmed.substring('HG_USER:'.length));
      if (userId != null && userId > 0) {
        return {'type': 'add_contact', 'user_id': userId};
      }
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final hasIdentity =
            decoded['user_id'] != null ||
            (decoded['email']?.toString().trim().isNotEmpty ?? false);
        if (hasIdentity) {
          return decoded;
        }
      }
    } catch (_) {}

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'healthguard' || uri.scheme == 'hg')) {
      final userIdFromUid = int.tryParse(uri.queryParameters['uid'] ?? '');
      final userIdFromPath = int.tryParse(
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '',
      );
      return {
        'type': 'add_contact',
        'user_id': userIdFromUid ?? userIdFromPath,
        'email': uri.queryParameters['email'],
        'full_name': uri.queryParameters['name'],
      };
    }

    // Fallback for simple QR formats: plain email or plain numeric user id
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (emailRegex.hasMatch(trimmed)) {
      return {'type': 'add_contact', 'email': trimmed};
    }

    final numericUserId = int.tryParse(trimmed);
    if (numericUserId != null && numericUserId > 0) {
      return {'type': 'add_contact', 'user_id': numericUserId};
    }

    return null;
  }

  Future<UserSearchModel?> _resolveUserFromQrPayload(
    Map<String, dynamic> payload,
  ) async {
    final qrEmail = payload['email']?.toString().trim();
    final qrUserId = (payload['user_id'] is int)
        ? payload['user_id'] as int
        : int.tryParse(payload['user_id']?.toString() ?? '');
    final qrName = payload['full_name']?.toString().trim();

    if (qrEmail != null && qrEmail.isNotEmpty) {
      final candidates = await _repository.searchUsers(qrEmail);

      for (final user in candidates) {
        final emailMatches = user.email.toLowerCase() == qrEmail.toLowerCase();
        final idMatches = qrUserId != null && user.id == qrUserId;
        if (emailMatches || idMatches) {
          return user;
        }
      }

      return UserSearchModel(
        id: qrUserId ?? 0,
        fullName: (qrName != null && qrName.isNotEmpty) ? qrName : 'Người dùng',
        email: qrEmail,
      );
    }

    if (qrUserId != null) {
      final candidates = await _repository.searchUsers(qrUserId.toString());
      for (final user in candidates) {
        if (user.id == qrUserId) {
          return user;
        }
      }

      return UserSearchModel(
        id: qrUserId,
        fullName: (qrName != null && qrName.isNotEmpty) ? qrName : 'Người dùng',
        email: 'user_$qrUserId@healthguard.local',
      );
    }

    return null;
  }

  Future<void> _openQrResultSheet(UserSearchModel user) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isSelfById =
        currentUser != null && user.id > 0 && user.id == currentUser.userId;
    final isSelfByEmail =
        currentUser != null &&
        user.email.isNotEmpty &&
        user.email.toLowerCase() == currentUser.email.toLowerCase();

    if (isSelfById || isSelfByEmail) {
      await _simulateScanSuccess(
        user,
        hideActions: true,
        showTags: false,
        statusMessage: 'Đây là mã QR của chính bạn.',
      );
      return;
    }

    if (user.connectionStatus == 'accepted') {
      await _simulateScanSuccess(
        user,
        hideActions: true,
        showTags: false,
        statusMessage: 'Đã liên kết.',
      );
      return;
    }

    if (user.connectionStatus == 'pending' && !user.isIncoming) {
      await _simulateScanSuccess(
        user,
        hideActions: true,
        showTags: false,
        statusMessage: 'Đã gửi lời mời.',
      );
      return;
    }

    if (user.connectionStatus == 'pending' && user.isIncoming) {
      await _simulateScanSuccess(
        user,
        isAccept: true,
        showTags: false,
        cancelButtonText: 'Hủy',
        confirmButtonText: 'Xác nhận',
      );
      return;
    }

    await _simulateScanSuccess(
      user,
      showTags: true,
      cancelButtonText: 'Hủy',
      confirmButtonText: 'Gửi lời mời',
    );
  }

  Future<void> _uploadQrImageFromDevice() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null || !mounted) {
        return;
      }

      final imagePath = pickedFile.path;
      if (imagePath == null || imagePath.isEmpty) {
        _simulateScanError();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh từ máy, đang xử lý mã QR...'),
          duration: Duration(milliseconds: 1200),
        ),
      );

      final rawQrData = await _decodeQrFromImagePath(imagePath);
      if (rawQrData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không đọc được mã QR từ ảnh đã chọn.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final payload = _parseAddContactQrPayload(rawQrData);
      if (payload == null) {
        _simulateScanError();
        return;
      }

      final user = await _resolveUserFromQrPayload(payload);
      if (user == null) {
        _simulateScanError();
        return;
      }

      await _openQrResultSheet(user);
    } catch (_) {
      if (!mounted) return;
      _simulateScanError();
    }
  }

  void _onShareMyCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bạn có thể chụp ảnh mã và gửi qua ứng dụng khác.'),
      ),
    );
  }

  Widget _buildUploadQrCard() {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _uploadQrImageFromDevice,
            icon: const Icon(Icons.image_rounded, size: 20),
            label: const Text(
              'Tải ảnh lên',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              foregroundColor: Colors.white,
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentModeView() {
    switch (_currentMode) {
      case AddContactMode.scan:
        return Padding(
          key: const ValueKey('scan_mode'),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: QRScannerViewport(
                  onSimulateScanSuccess: () => _simulateScanSuccess(null),
                  onSimulateScanError: _simulateScanError,
                ),
              ),
              _buildUploadQrCard(),
            ],
          ),
        );
      case AddContactMode.myCode:
        return Padding(
          key: const ValueKey('my_code_mode'),
          padding: const EdgeInsets.all(16),
          child: MyCodeHeroCard(
            qrData: _buildMyQrPayload(),
            pinCode: '482 931',
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
