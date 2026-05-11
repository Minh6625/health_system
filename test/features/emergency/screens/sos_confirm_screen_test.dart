import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/screens/sos_confirm_screen.dart';

Widget wrap(Widget child) {
  return MaterialApp(home: child);
}

bool _containsRichText(Widget widget, String expected) {
  return widget is RichText && widget.text.toPlainText().contains(expected);
}

void main() {
  testWidgets('defaults to manual SOS copy', (tester) async {
    await tester.pumpWidget(wrap(const SosConfirmScreen(recipientCount: 2)));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi SOS'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => _containsRichText(widget, 'Đã thông báo đến 2 người thân'),
      ),
      findsOneWidget,
    );
    expect(find.text('Đang chờ phản hồi'), findsOneWidget);
  });

  testWidgets('shows distinct risk escalation copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SosConfirmScreen(
          recipientCount: 4,
          mode: SosConfirmMode.riskEscalation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đã chuyển cảnh báo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => _containsRichText(
          widget,
          'Đã chuyển yêu cầu hỗ trợ đến 4 người thân',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Đang leo thang hỗ trợ'), findsOneWidget);
  });
}
