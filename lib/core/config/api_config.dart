class ApiConfig {
  static const String footballBaseUrl = 'https://v3.football.api-sports.io';

  static const String footballApiKey = '26021f33b052628209e55fa37d5e5f2d';

  static bool get hasFootballApiKey =>
      footballApiKey.trim().isNotEmpty;
}