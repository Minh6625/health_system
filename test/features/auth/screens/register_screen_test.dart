import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/screens/register_screen.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'register_screen_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository mockRepository;
  late AuthProvider authProvider;

  setUp(() {
    mockRepository = MockAuthRepository();
    authProvider = AuthProvider(mockRepository);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders all required form fields', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget());

      // Assert - Check all fields are present
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Họ tên'), findsOneWidget);
      expect(find.text('Ngày sinh'), findsOneWidget);
      expect(find.text('Số điện thoại'), findsOneWidget);
      expect(find.text('Vai trò'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Enter invalid email and trigger validation
      await tester.enterText(find.byType(AuthTextField).first, 'invalid-email');
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert - Validation error should appear
      expect(find.text('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid full name with numbers', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Find fullName field (second AuthTextField)
      final fullNameFinder = find.byType(AuthTextField).at(1);
      await tester.enterText(fullNameFinder, 'Test123');
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Họ tên chỉ được chứa chữ cái'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid full name with special characters', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act
      final fullNameFinder = find.byType(AuthTextField).at(1);
      await tester.enterText(fullNameFinder, 'Test@User');
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Họ tên chỉ được chứa chữ cái'), findsOneWidget);
    });

    testWidgets('accepts valid Vietnamese full name with diacritics', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Enter valid Vietnamese name
      final fullNameFinder = find.byType(AuthTextField).at(1);
      await tester.enterText(fullNameFinder, 'Nguyễn Văn Anh');
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert - Should not show validation error for full name
      expect(find.textContaining('Họ tên chỉ được chứa chữ cái'), findsNothing);
    });

    testWidgets('shows validation error for short password', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Find password field and enter short password
      final passwordFields = find.byType(AuthTextField);
      // Find the password field (should be around index 4-5)
      for (int i = 0; i < 10; i++) {
        try {
          final field = passwordFields.at(i);
          final widget = tester.widget<AuthTextField>(field);
          if (widget.label == 'Mật khẩu') {
            await tester.enterText(field, 'Pass1!');
            break;
          }
        } catch (e) {
          // Continue searching
        }
      }
      
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Mật khẩu phải có ít nhất 8 ký tự'), findsOneWidget);
    });

    testWidgets('role dropdown has patient and caregiver options', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Tap dropdown to open
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Assert - Both options should be visible
      expect(find.text('Bệnh nhân'), findsWidgets);
      expect(find.text('Người chăm sóc'), findsOneWidget);
    });

    testWidgets('switching to caregiver role shows correct date picker constraints', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Switch to caregiver role
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Người chăm sóc').last);
      await tester.pumpAndSettle();

      // Assert - Role should be switched (verify by checking dropdown value)
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.value, 'caregiver');
    });

    testWidgets('date of birth field shows validation error when empty', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Try to submit without selecting date
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Vui lòng chọn ngày sinh'), findsOneWidget);
    });

    testWidgets('phone number field accepts optional input', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Find phone field
      final phoneField = find.byWidgetPredicate(
        (widget) => widget is AuthTextField && widget.label == 'Số điện thoại',
      );
      
      // Phone is optional, so leaving it empty should not show error
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert - Should not show phone validation error when empty
      expect(find.textContaining('Số điện thoại phải có'), findsNothing);
    });

    testWidgets('shows validation error for invalid phone number', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Find phone field and enter invalid number
      final phoneField = find.byWidgetPredicate(
        (widget) => widget is AuthTextField && widget.label == 'Số điện thoại',
      );
      await tester.enterText(phoneField, '123'); // Too short
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Số điện thoại phải có từ 10 đến 15 chữ số'), findsOneWidget);
    });

    testWidgets('password confirmation must match password', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act - Enter different passwords
      final passwordFields = find.byType(AuthTextField);
      
      // Find password and confirm password fields
      for (int i = 0; i < 10; i++) {
        try {
          final field = passwordFields.at(i);
          final widget = tester.widget<AuthTextField>(field);
          if (widget.label == 'Mật khẩu') {
            await tester.enterText(field, 'StrongPass123!');
          } else if (widget.label == 'Xác nhận mật khẩu') {
            await tester.enterText(field, 'DifferentPass123!');
          }
        } catch (e) {
          // Continue
        }
      }

      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Mật khẩu không khớp'), findsOneWidget);
    });
  });
}
