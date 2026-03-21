import 'package:flutter/material.dart';

class ContactsGroupHeader extends StatelessWidget {
  final String title;
  final Color color;

  const ContactsGroupHeader({
    super.key,
    required this.title,
    this.color = const Color(0xFF12304A),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            semanticsLabel: 'Nhóm: $title',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

