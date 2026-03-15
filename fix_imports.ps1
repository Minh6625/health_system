
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\home\screens\main_screen.dart"
$content = "import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';`n" + $content
Set-Content "C:\Dev\Project2\health_system\lib\features\home\screens\main_screen.dart" -Value $content

