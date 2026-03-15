
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\profile\providers\profile_provider.dart" -Raw
$replacement = @"
  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchProfile() async {
"@

$content = $content -replace "  Future<void> fetchProfile\(\) async \{", $replacement
Set-Content "C:\Dev\Project2\health_system\lib\features\profile\providers\profile_provider.dart" -Value $content

