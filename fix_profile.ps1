
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart"
$content = "import 'package:provider/provider.dart';`n" + $content
$content = $content -replace "      `n    \);`n  Widget _buildDeviceCard", "      `n    );`n  }`n`n  Widget _buildDeviceCard"
Set-Content "C:\Dev\Project2\health_system\lib\features\profile\screens\profile_screen.dart" -Value $content

