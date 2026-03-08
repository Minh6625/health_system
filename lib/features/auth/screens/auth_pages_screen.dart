import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/features/auth/screens/start_screen.dart';
import 'package:healthguard/features/auth/screens/login_screen.dart';

class AuthPagesScreen extends StatefulWidget {
  const AuthPagesScreen({super.key});

  @override
  State<AuthPagesScreen> createState() => _AuthPagesScreenState();
}

class _AuthPagesScreenState extends State<AuthPagesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // PageView with Start and Login screens - Enable swipe
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(), // Enable smooth swipe
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              // Close keyboard when swiping from login back to start
              if (index == 0) {
                FocusScope.of(context).unfocus();
              }
            },
            children: const [StartScreen(isInPageView: true), LoginScreen()],
          ),

          // Button "Bắt đầu ngay" - Show on Start page
          if (_currentPage == 0)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _currentPage == 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _animateToPage(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bắt đầu ngay',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Page Indicator với 2 dấu chấm
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      2,
                      (index) => GestureDetector(
                        onTap: () => _animateToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: _currentPage == index ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
