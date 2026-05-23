// App-wide constants for Kwandwe Map

class AppConstants {
  // Map tile file name — must match the file placed in:
  // android/app/src/main/assets/tiles/kwandwe_2024.mbtiles
  // The app copies this to device storage on first launch automatically.
  static const String mbtileFileName = 'kwandwe_2024.mbtiles';
  static const String mbtileAssetPath = 'tiles/kwandwe_2024.mbtiles';

  // Reserve approximate center — used for initial map position
  // Kwandwe Private Game Reserve, Eastern Cape
  static const double reserveLat = -33.1600;
  static const double reserveLng = 26.5800;
  static const double initialZoom = 13.0;
  static const double minZoom = 12.5; // Prevent zooming out past the reserve
  static const double maxZoom = 18.0;

  // Exact bounds of the MBTiles map to prevent scrolling out of bounds
  static const double boundsSouthWestLat = -33.236810;
  static const double boundsSouthWestLng = 26.434952;
  static const double boundsNorthEastLat = -33.050173;
  static const double boundsNorthEastLng = 26.634937;

  // Removed old string-based pin types in favor of the PinType enum
}
