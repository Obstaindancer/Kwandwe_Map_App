# Kwandwe Tactical Map App

A highly specialized, offline-first tactical map application designed specifically for the Kwandwe Private Game Reserve. Built to operate flawlessly in deep-field environments without internet connectivity, this tool empowers reserve management, rangers, and conservationists with precision navigation, tracking, and environmental awareness.

## 🚀 Core Features

### 🗺️ Offline-First Field Mapping
- **MBTiles Integration:** Utilizes high-resolution custom maps (GeoTIFF converted to MBTiles) stored locally on the device, ensuring zero reliance on cellular networks.
- **Global Satellite Fallback:** Seamlessly toggles to an online global satellite view for areas outside the primary reserve bounds or when running on the web.

### 📍 Tactical Navigation & Coordinate Management
- **Universal Coordinate Parser:** Instantly parses and navigates to coordinates in multiple formats used in field communications:
  - **MGRS** (Military Grid Reference System)
  - **DDM** (Degrees Decimal Minutes)
  - **DD** (Decimal Degrees)
  - **DMS** (Degrees Minutes Seconds)
- **Pin Dropping & Management:** Long-press to drop customizable tactical pins (Predator, Herbivore, POI) for tracking animal movements or points of interest. 
- **Clipboard Integration:** Easily copy exact coordinates from dropped pins for rapid radio communication.

### 🧭 Field Tracking & Orientation
- **Live GPS Positioning:** High-accuracy blue-dot positioning using device GPS hardware.
- **"Follow Me" Mode:** Automatically centers and updates the map based on user movement.
- **Compass & Rotation Lock:** Professional compass HUD with true North alignment and manual rotation lock to maintain precise field orientation.
- **Route Tracking:** Record drive tracks and patrol routes in real-time.

### 📏 Mission Planning Tools
- **Distance Measurement Tool:** Trace points along the map to calculate exact distances for route planning.
- **GPX Track Integration:** Import external GPX patrol tracks directly into the app, or share recorded routes with team members.

### ⛅ Environmental Dashboard
- **Weather & Wind Overlay:** Integrates localized weather reporting and renders dynamic "Wind Scent Cones" on the map based on live wind direction—crucial for predator tracking and approach planning.
- **Lunar Calendar:** Accurately calculates and displays the current moon phase with dynamic iconography to assist with night-time operations and visibility planning.

## 🛠️ Technology Stack

- **Framework:** Flutter & Dart
- **State Management:** Riverpod
- **Mapping Engine:** `flutter_map`
- **Offline Tiles:** `flutter_map_mbtiles` with SQLite bindings
- **Location Services:** `geolocator`, `flutter_compass`
- **Architecture:** Offline-only (V1), strictly modular, privacy-focused.

## 📱 Getting Started

### 1. Map Data Preparation
The application requires a valid `kwandwe_2024.mbtiles` file to function completely offline.
Place the generated map file in the following directory before building:
`android/app/src/main/assets/tiles/kwandwe_2024.mbtiles`

*(Note: The map automatically extracts to local device storage on first launch for optimized database reading).*

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Locally (Android/iOS)
```bash
flutter run
```

### 4. Build for Production (APK)
```bash
flutter build apk --release
```

## 🌐 Web Deployment (Management Testing)
The app is configured to automatically deploy to GitHub Pages via GitHub Actions upon merging to the `main` branch. 

When running on the web, the app intelligently bypasses the heavy offline SQLite database and falls back to a live Google Satellite view. This allows reserve management to test UI features, coordinate parsing, and measurement tools directly from their iOS or desktop browsers without installing the native app.

## 🔐 Security & Privacy
Designed with operational security in mind. V1 requires absolutely no logins, features no cloud backend, and stores all sensitive patrol and tracking data locally on the device storage. No location data is ever transmitted off-device.
