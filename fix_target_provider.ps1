
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Raw
$replacement = @"
  void clearData() {
    _profiles = [];
    _relationships = [];
    _currentProfile = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchProfiles() async {
"@

$content = $content -replace "  Future<void> fetchProfiles\(\) async \{", $replacement
Set-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Value $content

