
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"
$content = $content -replace "import 'package:healthguard/features/family/screens/search_user_screen.dart';`nclass _FamilyManagementScreenState", "class _FamilyManagementScreenState"
$content = "import 'package:healthguard/features/family/screens/search_user_screen.dart';`n" + $content
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

