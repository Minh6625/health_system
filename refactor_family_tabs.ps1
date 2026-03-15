
$content = Get-Content -Raw "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart"

# Change state class signature to use SingleTickerProviderStateMixin
$content = $content -replace "class _FamilyManagementScreenState extends State<FamilyManagementScreen> {", "import 'package:healthguard/features/family/screens/search_user_screen.dart';`nclass _FamilyManagementScreenState extends State<FamilyManagementScreen> with SingleTickerProviderStateMixin {`n  late TabController _tabController;"

# Update initState to initialize tab controller
$content = $content -replace "  void initState\(\) {`n    super.initState\(\);", "  void initState() {`n    super.initState();`n    _tabController = TabController(length: 2, vsync: this);"

# Update dispose
$content = $content -replace "  void dispose\(\) {`n    _emailController.dispose\(\);`n    super.dispose\(\);", "  void dispose() {`n    _emailController.dispose();`n    _tabController.dispose();`n    super.dispose();"

# Remove floating action button
$content = $content -replace "          floatingActionButton: FloatingActionButton\([\s\S]*?child: const Icon\(Icons.add\),`n          \),", ""

# Delete actions from appbar
$content = $content -replace "          appBar: AppBar\([\s\S]*?actions: \[`n              IconButton\([\s\S]*?tooltip: 'Tìm kiếm & Thêm người',`n              \),`n            \],`n          \),", "          appBar: AppBar(
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
                Tab(icon: Icon(Icons.search), text: 'Tìm kiếm người dùng'),
                Tab(icon: Icon(Icons.people), text: 'Danh sách liên kết'),
              ],
            ),
          ),"
          
          
$content = $content -replace "          body: targetProvider.isLoading[\s\S]*?            \),", "          body: TabBarView(
            controller: _tabController,
            children: [
              const UserSearchTab(),
              targetProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => targetProvider.fetchProfiles(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (pendingIn.isNotEmpty) ...[
                            const Text(
                              'Yêu cầu chờ xác nhận',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pendingIn.map((r) => _buildPendingInItem(r, targetProvider)),
                            const SizedBox(height: 24),
                          ],
                          if (pendingOut.isNotEmpty) ...[
                            const Text(
                              'Yêu cầu bạn đã gửi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pendingOut.map((r) => _buildPendingOutItem(r, targetProvider)),
                            const SizedBox(height: 24),
                          ],
                          const Text(
                            'Bệnh nhân / Người thân',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (accepted.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('Chưa có dữ liệu nào. Hãy tìm kiếm và liên kết!'),
                            )
                          else
                            ...accepted.map((r) => _buildAcceptedItem(r, myId, targetProvider)),
                        ],
                      ),
                    ),
            ],
          ),"

Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\family_management_screen.dart" -Value $content

