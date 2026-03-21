import 'package:flutter/material.dart';
import '../models/linked_contact_model.dart';
import 'pending_request_card.dart';

class PendingRequestsSection extends StatelessWidget {
  final List<LinkedContactModel> requests;

  const PendingRequestsSection({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFF2A93B)), // warning color
            const SizedBox(width: 8),
            const Text(
              'Cần xử lý ngay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF12304A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF2A93B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${requests.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requests.map((request) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PendingRequestCard(request: request),
        )),
      ],
    );
  }
}
