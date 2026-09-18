# Cineva Mobile (Flutter)

App Android/iOS gọi API Cineva qua luồng **OAuth2** (`POST /api/auth/token` + Bearer).

## Yêu cầu

- Flutter SDK (đã cài local: `%LOCALAPPDATA%\flutter`)
- Backend chạy tại máy host (mặc định port `8000`)
- Emulator Android dùng `10.0.2.2` để trỏ về localhost host

## Chạy

```powershell
cd mobile
$env:Path = "$env:LOCALAPPDATA\flutter\bin;$env:Path"

# Windows desktop
flutter run -d windows --dart-define=API_BASE=http://localhost:8000

# Chrome (web)
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000

# Android emulator
flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8000

# Máy thật (đổi IP LAN)
flutter run --dart-define=API_BASE=http://192.168.1.10:8000
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
