import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/routes/app_router.dart';

class StartScreen extends StatelessWidget {
  final bool isInPageView;

  const StartScreen({super.key, this.isInPageView = false});

  void _openLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    // Ẩn bàn phím ngay khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    // Điều chỉnh kích thước theo màn hình
    final logoHeight = isSmallScreen ? 200.0 : 280.0;
    final titleFontSize = isSmallScreen ? 32.0 : 40.0;
    final subtitleFontSize = isSmallScreen ? 18.0 : 20.0;
    final bodyFontSize = isSmallScreen ? 14.0 : 16.0;
    final spacing1 = isSmallScreen ? 8.0 : 20.0;
    final spacing2 = isSmallScreen ? 20.0 : 48.0;
    final spacing3 = isSmallScreen ? 12.0 : 24.0;
    final spacing4 = isSmallScreen ? 8.0 : 16.0;
    final spacing5 = isSmallScreen ? 24.0 : 40.0;

    return GestureDetector(
      onTap: () {
        // Ẩn bàn phím khi tap vào màn hình
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      // Language Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content with Footer
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: spacing1),

                          // Hero Section - Logo Only
                          Container(
                            height: logoHeight,
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          SizedBox(height: spacing2),

                          // Title Section
                          Text(
                            'HealthGuard',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: titleFontSize,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          SizedBox(height: spacing3),
                          Text(
                            'Chăm sóc sức khỏe gia đình bạn',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: subtitleFontSize,
                                ),
                          ),
                          SizedBox(height: spacing4),
                          Text(
                            'Theo dõi chỉ số từ smartwatch.\nCảnh báo sớm đột quỵ & té ngã.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: bodyFontSize,
                                  height: 1.5,
                                ),
                          ),
                          SizedBox(height: spacing5),

                          // Footer - Only show when not in PageView
                          if (!isInPageView) ...[
                            // Primary Button
                            SizedBox(
                              width: double.infinity,
                              height: isSmallScreen ? 52 : 60,
                              child: ElevatedButton(
                                onPressed: () => _openLogin(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: AppColors.primary.withOpacity(
                                    0.25,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Bắt đầu ngay',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Trust Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: Colors.grey[300]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'TIN CẬY & BẢO MẬT',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 10 : 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Colors.grey[300]),
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 12 : 20),

                            // Trust Indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mã hóa đầu cuối',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_active,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Hỗ trợ 24/7',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 16 : 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
