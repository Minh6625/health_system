class ApiEndpoints {
  static const String baseUrl = 'https://api.example.com';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String devices = '/devices';
  static const String latestVitals = '/vital-signs/latest';
  static const String latestSleep = '/sleep/latest';
  static const String sleepHistory = '/sleep/history';
  static const String profile = '/profile';

  const ApiEndpoints._();
}
