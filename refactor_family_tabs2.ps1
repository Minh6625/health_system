
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"

# Change tab styles from the image and words
$content = $content -replace "              tabs: const \[`n                Tab\(icon: Icon\(Icons.search\), text: 'Tìm kiếm người dùng'\),`n                Tab\(icon: Icon\(Icons.people\), text: 'Danh sách liên kết'\),`n              \],", "              tabs: const [
                Tab(icon: Icon(Icons.person_search), text: 'Tìm kiếm'),
                Tab(icon: Icon(Icons.people), text: 'Người thân'),
              ],"

Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

