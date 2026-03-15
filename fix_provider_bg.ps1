
$content = Get-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Raw

$replacement1 = @"
  Future<bool> acceptRequest(
    int relationshipId, {
    bool background = false,
  }) async {
    if (!background) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _repository.acceptRequest(relationshipId);
      await fetchProfiles(); // ALWAYS fetch to update global state
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!background) {
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }
"@

$replacement2 = @"
  Future<bool> removeRelationship(
    int relationshipId, {
    bool background = false,
  }) async {
    if (!background) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _repository.deleteRelationship(relationshipId);
      await fetchProfiles(); // ALWAYS fetch to update global state
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!background) {
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }
"@

$content = $content -replace "(?s)  Future<bool> acceptRequest\(.*?return false;`n    \}`n  \}", $replacement1
$content = $content -replace "(?s)  Future<bool> removeRelationship\(.*?return false;`n    \}`n  \}", $replacement2

Set-Content "C:\Dev\Project2\health_system\lib\features\family\providers\target_profile_provider.dart" -Value $content

