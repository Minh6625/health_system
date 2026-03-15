
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Raw
$content = $content -replace "(?s)  void clearData\(\) \{.*?\}`n`n  void clearData\(\) \{", "  void clearData() {"
Set-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Value $content

