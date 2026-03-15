
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Raw

$replacement = @"
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<ProfileProvider>().profile == null) {
        context.read<ProfileProvider>().fetchProfile();
      }
    });
  }

  @override
  void dispose() {
"@

$content = $content -replace "  @override`n  void dispose\(\) \{", $replacement
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Value $content

