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
  static const String profile = '/profile';

  const ApiEndpoints._();
}
