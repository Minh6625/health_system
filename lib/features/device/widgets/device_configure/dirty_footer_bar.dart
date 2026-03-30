import 'package:flutter/material.dart';

class DirtyFooterBar extends StatelessWidget {
  final bool isVisible;
  final bool isSaving;
  final VoidCallback onSave;

  const DirtyFooterBar({
    super.key,
    required this.isVisible,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: isVisible ? 100 : 0, // 100 ensures enough space for SafeArea + padding
      child: isVisible 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Có thay đổi chưa lưu', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF12304A))),
                          Text('Nhớ biểu quyết trước khi thoát', style: TextStyle(fontSize: 13, color: Color(0xFF5B7288))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isSaving ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
