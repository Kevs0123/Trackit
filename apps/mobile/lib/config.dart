class AppConfig {
  /// Change with:  flutter run -d chrome --dart-define=API_BASE=https://your-domain/api
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000/api');

  /// How often the tracking page refreshes (seconds) = "real-time" updates
  static const int pollSeconds = 10;
}
