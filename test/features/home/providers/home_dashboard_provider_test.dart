import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:healthguard/features/home/repositories/home_dashboard_repository.dart';

class _FakeHomeDashboardRepository extends HomeDashboardRepository {
  _FakeHomeDashboardRepository({
    this.throwVitals = false,
    this.throwHealth = false,
    this.throwSleep = false,
  });

  final bool throwVitals;
  final bool throwHealth;
  final bool throwSleep;
  final List<String?> requestedProfiles = [];

  @override
  Future<VitalSignsResponse> getLatestVitalSigns({String? profileId}) async {
    requestedProfiles.add(profileId);
    if (throwVitals) {
      throw Exception('vitals failed');
    }
    return VitalSignsResponse(
      heartRate: 72,
      spo2: 98,
      temperature: 36.7,
      respiratoryRate: 16,
      bloodPressureSys: 118,
      bloodPressureDia: 76,
      timestamp: DateTime.utc(2026, 4, 19, 8),
      isStale: false,
    );
  }

  @override
  Future<HealthReportResponse> getHealthReport({String? profileId}) async {
    requestedProfiles.add(profileId);
    if (throwHealth) {
      throw Exception('health failed');
    }
    return HealthReportResponse(
      vitals24hAvg: const {'avg_hr': 72},
      latestRiskScore: 18,
      healthScore: 82,
      healthLevel: 'good',
      healthSummary: 'Ổn định.',
      riskLevel: 'low',
      riskType: 'general',
      lastUpdated: DateTime.utc(2026, 4, 19, 8),
      confidence: 0.92,
      isStale: false,
    );
  }

  @override
  Future<Map<String, dynamic>?> getLatestSleepSession({
    String? profileId,
  }) async {
    requestedProfiles.add(profileId);
    if (throwSleep) {
      throw Exception('sleep failed');
    }
    return const {'quality_score': 84, 'in_bed_minutes': 430};
  }
}

void main() {
  group('HomeDashboardProvider', () {
    test(
      'propagates linked profile id across every dashboard section fetch',
      () async {
        final repository = _FakeHomeDashboardRepository();
        final provider = HomeDashboardProvider(
          repository: repository,
          profileId: '42',
        );

        await provider.loadDashboardData();

        expect(repository.requestedProfiles, ['42', '42', '42']);
        expect(provider.error, isNull);
        expect(provider.healthScore, 82);
      },
    );

    test(
      'keeps successful sections while exposing partial section errors',
      () async {
        final repository = _FakeHomeDashboardRepository(throwSleep: true);
        final provider = HomeDashboardProvider(repository: repository);

        await provider.loadDashboardData();

        expect(provider.heartRate, 72);
        expect(provider.healthScore, 82);
        expect(provider.sleepData, isNull);
        expect(provider.error, isNull);
        expect(provider.hasSectionErrors, isTrue);
        expect(
          provider.sectionErrors.containsKey(HomeDashboardSection.sleep),
          isTrue,
        );
        expect(provider.sectionErrorMessage, contains('giấc ngủ'));
      },
    );

    test(
      'surfaces combined error when every dashboard section fails',
      () async {
        final repository = _FakeHomeDashboardRepository(
          throwVitals: true,
          throwHealth: true,
          throwSleep: true,
        );
        final provider = HomeDashboardProvider(repository: repository);

        await provider.loadDashboardData();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('chỉ số sinh tồn'));
        expect(provider.error, contains('điểm sức khỏe'));
        expect(provider.error, contains('giấc ngủ'));
      },
    );
  });
}
