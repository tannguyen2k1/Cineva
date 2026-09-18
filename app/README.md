# Cineva App (Flutter)

App iOS/Android gọi API Cineva qua luồng **OAuth2** (`POST /api/auth/token` + Bearer).

## Yêu cầu

- Flutter SDK
- Xcode + CocoaPods (iOS)
- Backend chạy tại máy host (mặc định port `8000`)

## Chạy

```bash
cd app
flutter pub get

# iOS Simulator (localhost của Mac)
flutter run --dart-define=API_BASE=http://127.0.0.1:8000

# Android emulator (host = 10.0.2.2)
flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8000

# Chrome (web)
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000

# Máy thật (đổi IP LAN)
flutter run --dart-define=API_BASE=http://192.168.1.10:8000
```

Windows desktop (nếu cần):

```powershell
cd app
$env:Path = "$env:LOCALAPPDATA\flutter\bin;$env:Path"
flutter run -d windows --dart-define=API_BASE=http://localhost:8000
```

## Cấu trúc

```
lib/
  main.dart
  src/
    config/app_config.dart
    models/
    services/api_client.dart   # login/refresh/films/detail
    state/auth_state.dart
    screens/                   # login, home, detail, watch
    app_router.dart
```

Player lấy `m3u8` từ query `url=` trong `link_embed` KKPhim khi có.
