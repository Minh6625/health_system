import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w400,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }
}
