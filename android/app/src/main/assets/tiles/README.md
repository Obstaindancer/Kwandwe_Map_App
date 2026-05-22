# Android Native Assets — Map Tiles

Place your converted MBTiles file here:

  android/app/src/main/assets/tiles/kwandwe_2024.mbtiles

This folder is bundled directly into the APK as a raw Android asset.
Flutter does NOT compress or process this file — it goes in as-is.

## Why here and not in Flutter assets/?

Flutter's asset pipeline compresses everything, which corrupts binary
tile files. Android native assets bypass this and bundle the file raw.

## How the app reads it

The app copies the file from the APK assets to device storage on first
launch, then reads it from there. This is the standard approach for
large map files bundled in Android apps.

## File size

Sideloaded APKs have NO size limit. A 50-150MB APK is perfectly fine
for distribution via USB, WhatsApp, or direct download link.

## Conversion reminder

  sudo pacman -S gdal
  gdal_translate -of MBTiles your_kwandwe_map.tif kwandwe_2024.mbtiles
  gdaladdo -r average kwandwe_2024.mbtiles 2 4 8 16
