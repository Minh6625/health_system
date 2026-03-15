
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Raw

$replacement = @"
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<ProfileProvider>().profile == null) {
        context.read<ProfileProvider>().fetchProfile();
      }
      context.read<TargetProfileProvider>().fetchProfiles();
    });
  }
"@

$content = $content -replace "(?s)  @override`n  void initState\(\) \{.*?    \}\);`n  \}", $replacement
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

