import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vital_signs.dart';
import '../providers/vital_signs_provider.dart';
import '../widgets/vital_card.dart';
import '../widgets/timestamp_badge.dart';
import '../widgets/vital_grid_skeleton.dart';
import '../widgets/blood_pressure_card.dart';
// Removed unused import
import '../widgets/health_report_banner.dart';
import '../screens/vital_detail_screen.dart';
import '../screens/health_report_screen.dart';

class HealthMonitoringScreen extends StatefulWidget {
  const HealthMonitoringScreen({super.key});

  @override
  State<HealthMonitoringScreen> createState() => _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen>
    with TickerProviderStateMixin {
  // Staggered entrance animation controller
  late AnimationController _entranceController;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  // Track whether we've run the entrance animation yet
  bool _entrancePlayed = false;

  static const int _animatedItemCount = 4; // badge, grid, BP card, report banner

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Build staggered fade + slide for each section
    _itemFades = List.generate(_animatedItemCount, (i) {
      final start = i * 0.18;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _itemSlides = List.generate(_animatedItemCount, (i) {
      final start = i * 0.18;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    // Trigger initial fetch + auto-refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VitalSignsProvider>();
      provider.fetchLatestVitals();
      provider.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    context.read<VitalSignsProvider>().stopAutoRefresh();
    super.dispose();
  }

  void _playEntranceIfNeeded() {
    if (!_entrancePlayed) {
      _entrancePlayed = true;
      _entranceController.forward();
    }
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _itemFades[index],
      child: SlideTransition(
        position: _itemSlides[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<VitalSignsProvider>(
        builder: (context, provider, child) {
          // ── Loading State ──────────────────────────────────────────────────
          if (provider.isLoading && provider.currentVitals == null) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(provider, isLoading: true),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const VitalGridSkeleton(),
                    ]),
                  ),
                ),
              ],
            );
          }

          // ── Error State ────────────────────────────────────────────────────
          if (provider.errorMessage != null && provider.currentVitals == null) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(provider),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => provider.fetchLatestVitals(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(150, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // ── Empty State ────────────────────────────────────────────────────
          final vitals = provider.currentVitals;
          if (vitals == null) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(provider),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có dữ liệu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hãy đảm bảo thiết bị đồng hồ đang kết nối.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => provider.fetchLatestVitals(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Làm mới'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // ── Success State ──────────────────────────────────────────────────
          _playEntranceIfNeeded();

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchLatestVitals();
            },
            child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(provider),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 0 — Timestamp badge
                    _animated(0, TimestampBadge(vitals: vitals)),
                    const SizedBox(height: 16),

                    // 1 — Vital cards grid
                    _animated(1, _buildVitalGrid(vitals)),
                    const SizedBox(height: 12),

                    // 2 — Blood pressure card
                    _animated(
                      2,
                      BloodPressureCard(
                        vitals: vitals,
                        onTap: () {
                          final sysStatus = vitals.getBloodPressureSysStatus();
                          final diaStatus = vitals.getBloodPressureDiaStatus();
                          final status = sysStatus.index > diaStatus.index ? sysStatus : diaStatus;
                          final sysStr = vitals.bloodPressureSys?.toStringAsFixed(0) ?? '--';
                          final diaStr = vitals.bloodPressureDia?.toStringAsFixed(0) ?? '--';
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VitalDetailScreen(
                                title: 'Huyết áp',
                                value: '$sysStr / $diaStr',
                                unit: 'mmHg',
                                status: status,
                                chartData: const [
                                  [120, 122, 118, 125, 130, 128, 120, 118], // Sys
                                  [80, 82, 78, 85, 88, 85, 80, 78], // Dia
                                ],
                                chartColors: [Colors.purple.shade400, Colors.teal.shade400],
                                educationText: 'Huyết áp bình thường của người lớn tuổi nên duy trì dưới 140/90 mmHg. Nếu vượt quá, cần nghỉ ngơi và theo dõi sát.',
                                onSosTap: () {/* TODO: Auto-trigger SOS */},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3 — Health Report Banner (replaces QuickActionsPanel)
                    _animated(
                      3,
                      HealthReportBanner(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HealthReportScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  // ── SliverAppBar ────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(
    VitalSignsProvider provider, {
    bool isLoading = false,
  }) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 0,
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      title: const Text(
        'Giám Sát Sức Khỏe',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade700, Colors.blue.shade600],
            ),
          ),
        ),
      ),
      actions: [
        if (provider.isLoading && provider.currentVitals != null)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ),
        if (!isLoading)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => provider.fetchLatestVitals(),
            tooltip: 'Làm mới',
          ),
      ],
    );
  }

  // ── Vital Grid ──────────────────────────────────────────────────────────────

  Widget _buildVitalGrid(VitalSigns vitals) {
    void navTo(String title, String val, String unit, VitalStatus st, List<double> chart, Color c, String edu) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VitalDetailScreen(
            title: title,
            value: val,
            unit: unit,
            status: st,
            chartData: [chart],
            chartColors: [c],
            educationText: edu,
            onSosTap: () {},
          ),
        ),
      );
    }

    final cards = [
      VitalCard(
        title: 'Nhịp tim',
        value: vitals.heartRate?.toStringAsFixed(0) ?? '--',
        unit: 'BPM',
        icon: Icons.favorite,
        status: vitals.getHeartRateStatus(),
        onTap: () => navTo(
          'Nhịp tim',
          vitals.heartRate?.toStringAsFixed(0) ?? '--',
          'BPM',
          vitals.getHeartRateStatus(),
          [72, 75, 78, 85, 82, 76, 74, 72],
          Colors.red.shade400,
          'Nhịp tim bình thường của người lớn tuổi lúc nghỉ ngơi là từ 60-100 BPM. Tập thể dục nhẹ có thể làm tăng nhịp tim tạm thời.',
        ),
      ),
      VitalCard(
        title: 'Oxy máu',
        value: vitals.spo2?.toStringAsFixed(1) ?? '--',
        unit: '%',
        icon: Icons.water_drop,
        status: vitals.getSpo2Status(),
        onTap: () => navTo(
          'Nồng độ Oxy máu',
          vitals.spo2?.toStringAsFixed(1) ?? '--',
          '%',
          vitals.getSpo2Status(),
          [98, 97, 98, 99, 98, 97, 96, 98],
          Colors.blue.shade400,
          'SpO2 nên duy trì trên 95%. Nếu chỉ số này nhỏ hơn 92%, bệnh nhân có thể đang thiếu oxy nghiêm trọng.',
        ),
      ),
      VitalCard(
        title: 'Nhiệt độ',
        value: vitals.temperature?.toStringAsFixed(1) ?? '--',
        unit: '°C',
        icon: Icons.thermostat,
        status: vitals.getTemperatureStatus(),
        onTap: () => navTo(
          'Nhiệt độ cơ thể',
          vitals.temperature?.toStringAsFixed(1) ?? '--',
          '°C',
          vitals.getTemperatureStatus(),
          [36.5, 36.6, 36.7, 36.8, 36.6, 36.5, 36.4, 36.5],
          Colors.orange.shade400,
          'Nhiệt độ trung bình là 36.5°C đến 37.2°C. Trẻ em và người già có thể có khoảng nhiệt độ này thay đổi đôi chút.',
        ),
      ),
      VitalCard(
        title: 'Nhịp thở',
        value: vitals.respiratoryRate?.toStringAsFixed(0) ?? '--',
        unit: '/phút',
        icon: Icons.air,
        status: vitals.getRespiratoryRateStatus(),
        onTap: () => navTo(
          'Nhịp thở',
          vitals.respiratoryRate?.toStringAsFixed(0) ?? '--',
          'nhịp/phút',
          vitals.getRespiratoryRateStatus(),
          [16, 17, 18, 16, 15, 16, 17, 16],
          Colors.teal.shade400,
          'Nhịp thở bình thường từ 12-20 lần/phút. Thở nhanh (>25 lần/phút) có thể là dấu hiệu suy hô hấp.',
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Fixed height per tile — cards expand vertically, never clip content.
        // Safe even at OS text scale 200% because content uses FittedBox inside.
        mainAxisExtent: 160,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
    );
  }
}

