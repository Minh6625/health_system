import 'package:flutter/material.dart';
import 'package:healthguard/features/auth/screens/login_screen.dart';
import 'package:healthguard/features/auth/screens/start_screen.dart';
import 'package:healthguard/features/auth/widgets/auth_pages/auth_get_started_cta.dart';
import 'package:healthguard/features/auth/widgets/auth_pages/auth_page_indicator.dart';

/// Two-page on-boarding flow: welcome (Start) + login form.
///
/// The screen owns the `PageController` and the `_currentPage` index used
/// for the dot indicator + the welcome-page CTA. The CTA visuals and the
/// dot indicator both live in their own widgets so this file stays
/// focused on the page wiring.
class AuthPagesScreen extends StatefulWidget {
  const AuthPagesScreen({super.key});

  @override
  State<AuthPagesScreen> createState() => _AuthPagesScreenState();
}

class _AuthPagesScreenState extends State<AuthPagesScreen> {
  static const int _pageCount = 2;
  static const int _welcomePageIndex = 0;
  static const int _loginPageIndex = 1;

  final PageController _pageController = PageController();
  int _currentPage = _welcomePageIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _slideToLogin() {
    _pageController.animateToPage(
      _loginPageIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCta = _currentPage == _welcomePageIndex;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: const [
              StartScreen(isInPageView: true),
              LoginScreen(),
            ],
          ),
          if (showCta)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: AuthGetStartedCta(onTap: _slideToLogin),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: AuthPageIndicator(
              pageCount: _pageCount,
              currentPage: _currentPage,
            ),
          ),
        ],
      ),
    );
  }
}
