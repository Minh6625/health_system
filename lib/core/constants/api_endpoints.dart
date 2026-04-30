class ApiEndpoints {
  static const String baseUrl = 'https://api.example.com';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String devices = '/devices';
  static const String latestVitals = '/metrics/vital-signs/latest';
  static const String latestSleep = '/metrics/sleep/latest';
  static const String sleepHistory = '/metrics/sleep/history';
  static const String healthReport = '/metrics/health-report';
  static const String vitalsLatest = latestVitals;
  // F-12 (M-6): downsampled vitals time-series for the chart on
  // `vital_detail_screen.dart`. Path mirrors the FastAPI route mounted
  // at `metrics_router.get("/vitals/timeseries", ...)` in
  // `app/api/routes/monitoring.py`.
  static const String vitalsTimeseries = '/metrics/vitals/timeseries';
  static const String profile = '/profile';

  // Fall events — Phase 4B-full slice 2c
  static const String fallEvents = '/fall-events';

  /// Build the path for one fall event by id, e.g. ``/fall-events/17``.
  static String fallEventDetail(int id) => '$fallEvents/$id';

  /// Build the dismiss path for one fall event, e.g.
  /// ``/fall-events/17/dismiss``.
  static String fallEventDismiss(int id) => '$fallEvents/$id/dismiss';

  const ApiEndpoints._();
}
