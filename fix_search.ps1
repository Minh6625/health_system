
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart"
$content = $content -replace "class SearchUserScreen", "class UserSearchTab"
$content = $content -replace "State<SearchUserScreen> createState\(\) => _SearchUserScreenState\(\);", "State<UserSearchTab> createState() => _UserSearchTabState();"
$content = $content -replace "class _SearchUserScreenState extends State<SearchUserScreen> {", "import 'dart:async';`nclass _UserSearchTabState extends State<UserSearchTab> {`n  Timer? _debounce;`n"
$content = $content -replace "  @override`n  void dispose\(\) {`n    _searchController.dispose\(\);`n    super.dispose\(\);`n  }", "  @override`n  void dispose() {`n    _searchController.dispose();`n    _debounce?.cancel();`n    super.dispose();`n  }"
$content = $content -replace "onSubmitted: _performSearch,", "onChanged: _onSearchChanged,"
$content = $content -replace "  Future<void> _performSearch", "  void _onSearchChanged(String query) {`n    if (_debounce?.isActive ?? false) _debounce?.cancel();`n    _debounce = Timer(const Duration(milliseconds: 500), () {`n      _performSearch(query);`n    });`n  }`n`n  Future<void> _performSearch"
$content = $content -replace "return Scaffold\(`n      appBar: AppBar\(title: const Text\('Tìm kiếm người dùng'\)\),`n      body: Column\(", "return Column("
$content = $content -replace "        \]`,`n      \),`n    \);", "        ]," + "\n    );"
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Value $content

