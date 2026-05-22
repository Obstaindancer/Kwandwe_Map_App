# Kwandwe Powerhouse Map

Offline GPS map app for Kwandwe Private Game Reserve.

## V1 Features
- Offline map from custom MBTiles (converted from GeoTIFF)
- Live GPS blue-dot positioning
- Paste rhino collar coordinates → map flies to location
- Long-press to drop manual pins
- No internet required, no login, no backend

## Setup

### 1. Convert your map file first
See `assets/tiles/README.md` for GDAL conversion instructions.

### 2. Install Flutter dependencies
```bash
flutter pub get
```

### 3. Run on Android device
```bash
flutter run
```

### 4. Build APK
```bash
flutter build apk --release
```

## Project Docs
- `plan.md` — full project plan, phases, schema
- `agent.md` — AI agent rules and guardrails

## Stack
- Flutter + Riverpod
- flutter_map + MBTiles
- geolocator
- No backend (V1)
