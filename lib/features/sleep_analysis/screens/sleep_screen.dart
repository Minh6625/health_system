import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:provider/provider.dart';
import '../../family/widgets/profile_switcher.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  static const List<String> _weekDays = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];
  static const List<double> _fallbackWave = [
    0.95,
    0.15,
    0.32,
    0.58,
    0.14,
    0.43,
    0.67,
    0.27,
    0.11,
    0.38,
    0.74,
    0.52,
    0.33,
    0.28,
    0.92,
    0.87,
    0.31,
    0.46,
    0.12,
    0.18,
    0.89,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepProvider>().fetchLatestSleep();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final chartHeight = size.height * 0.25;

    return Scaffold(
      backgroundColor: const Color(0xFF07162B),
      appBar: AppBar(
        title: const Text('Giấc ngủ'),
        backgroundColor: const Color(0xFF07162B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ProfileSwitcher(
                onProfileChanged: () {
                  context.read<SleepProvider>().fetchLatestSleep();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SleepProvider>().fetchLatestSleep();
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<SleepProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.latestSession == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage != null &&
                provider.latestSession == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white70,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.fetchLatestSleep(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final session = provider.latestSession;
            final wave = session == null
                ? _fallbackWave
                : _buildWave(session.phases);

            return RefreshIndicator(
              onRefresh: () => provider.fetchLatestSleep(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF10233F), Color(0xFF07162B)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2B48D6FF),
                        blurRadius: 26,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0x332C4367),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(session),
                      const SizedBox(height: 14),
                      _buildWeekSelector(),
                      const SizedBox(height: 18),
                      _buildSummary(session),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: const Color(0x334B5E82),
                      ),
                      const SizedBox(height: 18),
                      _buildChartSection(chartHeight, wave, session),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(SleepSession? session) {
    final start = session?.startTime ?? DateTime.now();
    final end = session?.endTime ?? DateTime.now();
    final weekday = _weekdayLabel(end.weekday);
    final dateLabel = '${start.day}-${end.day} ${_monthLabel(end.month)}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                dateLabel,
                style: TextStyle(
                  color: Color(0xFF7E9BC2),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0x1A4EDAFF),
            border: Border.all(color: const Color(0x663DA6D8), width: 1),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: Color(0xFF7AC8FF),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_weekDays.length, (index) {
        final selected = index == 3;
        return Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0x2EFFC400) : const Color(0xFF14253D),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFC400)
                  : const Color(0xFF3C4D69),
              width: selected ? 3 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _weekDays[index],
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFFC400)
                  : const Color(0xFF93A9C8),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummary(SleepSession? session) {
    final quality = session?.qualityScore ?? 80;
    final ratio = session?.qualityRatio ?? 0.8;
    final inBed = session?.inBedText ?? '7h 45m';
    final wakeCount = session?.wakeCount ?? 0;

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _QualityRingPainter(value: ratio),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$quality%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Chất lượng',
                  style: TextStyle(color: Color(0xFF90A6C3), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inBed,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'Trên giường',
                style: TextStyle(
                  color: Color(0xFF90A6C3),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Số lần thức giấc: $wakeCount\nDữ liệu cập nhật từ backend.',
                style: TextStyle(
                  color: Color(0xFF6F8AAE),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection(
    double chartHeight,
    List<double> wave,
    SleepSession? session,
  ) {
    const labels = ['Thức', 'Ngủ', 'Ngủ sâu'];
    final timeLabels = _buildTimeLabels(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labels[0],
                      style: TextStyle(color: Color(0xFF95A8C7), fontSize: 13),
                    ),
                    Text(
                      labels[1],
                      style: TextStyle(color: Color(0xFF95A8C7), fontSize: 13),
                    ),
                    Text(
                      labels[2],
                      style: TextStyle(color: Color(0xFF95A8C7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(painter: _SleepChartPainter(points: wave)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: Color(0x334B5E82), height: 1),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(left: 64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thời gian',
                style: TextStyle(color: Color(0xFF95A8C7), fontSize: 13),
              ),
              Text(
                'Ngáy',
                style: TextStyle(color: Color(0xFF95A8C7), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: timeLabels
                .map(
                  (label) => Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFB8CAE3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SnoreDot(active: false),
              _SnoreDot(active: false),
              _SnoreDot(active: true),
              _SnoreDot(active: false),
              _SnoreDot(active: true),
              _SnoreDot(active: false),
              _SnoreDot(active: false),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _buildTimeLabels(SleepSession? session) {
    if (session == null) {
      return ['23', '00', '01', '02', '03', '04', '05', '06'];
    }

    final labels = <String>[];
    final start = session.startTime;
    for (var i = 0; i < 8; i++) {
      final point = start.add(Duration(hours: i));
      labels.add(point.hour.toString().padLeft(2, '0'));
    }
    return labels;
  }

  List<double> _buildWave(Map<String, int> phases) {
    final awake = phases['awake'] ?? 30;
    final light = phases['light'] ?? 180;
    final deep = phases['deep'] ?? 90;
    final rem = phases['rem'] ?? 60;
    final total = awake + light + deep + rem;

    if (total <= 0) {
      return _fallbackWave;
    }

    final awakeRatio = awake / total;
    final lightRatio = light / total;
    final deepRatio = deep / total;
    final remRatio = rem / total;

    return [
      0.9,
      0.2,
      0.45,
      0.6 * lightRatio + 0.2,
      0.15,
      0.4 * deepRatio + 0.35,
      0.7,
      0.28,
      0.16,
      0.55 * remRatio + 0.35,
      0.74,
      0.52,
      0.33,
      0.25 + awakeRatio,
      0.92,
      0.7,
      0.31,
      0.46,
      0.18,
      0.2,
      0.86,
    ];
  }

  String _weekdayLabel(int weekday) {
    const labels = [
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
      'Chủ nhật',
    ];
    return labels[weekday - 1];
  }

  String _monthLabel(int month) {
    const labels = [
      'Thg 1',
      'Thg 2',
      'Thg 3',
      'Thg 4',
      'Thg 5',
      'Thg 6',
      'Thg 7',
      'Thg 8',
      'Thg 9',
      'Thg 10',
      'Thg 11',
      'Thg 12',
    ];
    return labels[month - 1];
  }
}

class _SnoreDot extends StatelessWidget {
  final bool active;

  const _SnoreDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: active ? 12 : 8,
      height: active ? 12 : 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF46D8FF) : const Color(0xFF395578),
        shape: BoxShape.circle,
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color(0x6646D8FF),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _QualityRingPainter extends CustomPainter {
  final double value;

  const _QualityRingPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = const Color(0xFF1E3352)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progress = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFFFEE58), Color(0xFFFFC400)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      6.28318 * value,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _QualityRingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _SleepChartPainter extends CustomPainter {
  final List<double> points;

  const _SleepChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x263D5E85)
      ..strokeWidth = 1;

    for (var i = 0; i <= 6; i++) {
      final x = (size.width / 6) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (size.height * points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = const Color(0x5540D8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3ACDFF), Color(0xFF57E2FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SleepChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
