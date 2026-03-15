
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"
$content = $content -replace "          floatingActionButton: FloatingActionButton\([\s\S]*?child: const Icon\(Icons.add\),`n          \),", ""
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

