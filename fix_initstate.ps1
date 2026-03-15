
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"

$content = $content -replace "  void initState\(\) {`n    super.initState\(\);`n    WidgetsBinding.instance.addPostFrameCallback\(", "  void initState() {`n    super.initState();`n    _tabController = TabController(length: 2, vsync: this);`n    WidgetsBinding.instance.addPostFrameCallback("

$content = $content -replace "  void dispose\(\) {`n    _emailController.dispose\(\);`n    super.dispose\(\);", "  void dispose() {`n    _emailController.dispose();`n    _tabController.dispose();`n    super.dispose();"
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

