class ApiEndpoints {
  static const String baseUrl = 'https://api.example.com';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String devices = '/mobile/devices';
  static const String latestVitals = '/mobile/vital-signs/latest';
  static const String latestSleep = '/mobile/sleep/latest';
  static const String profile = '/mobile/profile';

  const ApiEndpoints._();
}
