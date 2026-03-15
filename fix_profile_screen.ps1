
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart" -Raw
$replacement = @"
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      context.read<ProfileProvider>().clearProfile();
      context.read<TargetProfileProvider>().clearData();
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    }
  }
"@

# We use regex to replace the function
$content = $content -replace "(?s)  Future<void> _confirmLogout\(\) async \{.*?(?=  @override`n  Widget build)", "$replacement`n`n"
Set-Content "C:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart" -Value $content

