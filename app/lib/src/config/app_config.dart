/// App config. Override API base at build time:
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:8000`
class AppConfig {
  AppConfig._();

  /// Desktop / iOS simulator: localhost
  /// Android emulator: http://10.0.2.2:8000
  /// Physical device: your LAN IP, e.g. http://192.168.1.10:8000
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );
}
