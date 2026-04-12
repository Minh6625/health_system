import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/widgets/start/start_screen_content.dart';
import 'package:healthguard/features/auth/widgets/start/start_screen_footer.dart';
import 'package:healthguard/features/auth/widgets/start/start_screen_header.dart';
import 'package:healthguard/features/auth/widgets/start/start_screen_hero.dart';

class StartScreen extends StatelessWidget {
  final bool isInPageView;

  const StartScreen({super.key, this.isInPageView = false});

  void _openLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final spacing1 = isSmallScreen ? 8.0 : 20.0;
    final spacing2 = isSmallScreen ? 20.0 : 48.0;
    final spacing5 = isSmallScreen ? 24.0 : 40.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.brandPrimaryLight, AppColors.bgSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const StartScreenHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: AppSpacing.screenHorizontalPadding,
                    child: Column(
                      children: [
                        SizedBox(height: spacing1),
                        const StartScreenHero(),
                        SizedBox(height: spacing2),
                        const StartScreenContent(),
                        SizedBox(height: spacing5),
                        if (!isInPageView)
                          StartScreenFooter(
                            onGetStarted: () => _openLogin(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
