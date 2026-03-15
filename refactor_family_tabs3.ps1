
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"

$content = $content -replace "          appBar: AppBar\([\s\S]*?body: TabBarView\(", "          appBar: AppBar(
            title: const Text('Quản lý Gia đình'),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.person_search), text: 'Tìm kiếm'),
                Tab(icon: Icon(Icons.people), text: 'Người thân'),
              ],
            ),
          ),
          body: TabBarView("

Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

