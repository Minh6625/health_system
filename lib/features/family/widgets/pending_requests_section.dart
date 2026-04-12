import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import '../models/linked_contact_model.dart';
import 'pending_request_card.dart';

class PendingRequestsSection extends StatelessWidget {
  final List<LinkedContactModel> requests;

  const PendingRequestsSection({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();

    bool hasIncoming = requests.any((req) => req.isIncomingRequest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              color: hasIncoming ? AppColors.warning : Colors.blueGrey,
            ), // warning color
            const SizedBox(width: 8),
            Text(
              hasIncoming ? 'Cần xử lý ngay' : 'Đang chờ xác nhận',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: hasIncoming ? AppColors.warning : Colors.blueGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${requests.length}',
                style: const TextStyle(
                  color: AppColors.bgSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requests.map(
          (request) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PendingRequestCard(request: request),
          ),
        ),
      ],
    );
  }
}
