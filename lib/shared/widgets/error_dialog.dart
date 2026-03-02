import 'package:flutter/material.dart';

Future<void> showErrorDialog(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lỗi'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
