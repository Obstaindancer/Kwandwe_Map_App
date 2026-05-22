# Kwandwe Powerhouse Map — Project Plan

**Last updated:** Project session 1 — foundation complete

---

## Project Overview

A Flutter-based offline map application for Kwandwe Private Game Reserve. Built to replace Avenza Maps with a fully custom, paywall-free solution. The app bundles the reserve's own cartographic map directly inside the APK — one download, works completely offline with no setup required.

V1 is a standalone tool: offline map, live GPS, and coordinate locator for rhino collar alerts. V2 adds Supabase backend, shared real-time markers, road condition reporting, and user roles.

---

## Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| Mobile App | Flutter (Dart) | Cross-platform, already used at Kwandwe |
| Map Rendering | flutter_map | Open source, no paywall |
| Offline Tiles | MBTiles + flutter_map_mbtiles | Tiled format, fast random access |
| Tile Bundling | Android native assets | Bypasses Flutter compression — raw binary safe |
| GPS | geolocator | Real-time device positioning |
| Compass | flutter_compass | Compass rose overlay |
| State Management | Riverpod | Scalable, Flutter-native |
| Backend / Auth | Supabase (V2 only) | Postgres + RLS, already familiar |
| Real-time Sync | Supabase Realtime (V2 only) | Live marker updates |
| Offline Queue | sqflite or Hive (V2 only) | Queue writes when no signal |

---

## Map Assets

### Source Map File

| Property | Value |
|---|---|
| **File name** | Kwandwe Road Map_2024_Cartographic_modified |
| **Format** | GeoTIFF (.tif) |
| **Coordinate system** | WGS 84 (EPSG:4326) — matches GPS natively, no reprojection needed |
| **Resolution** | 10,644 × 9,934 pixels |
| **Origin** | Avenza Maps export |
| **Content** | All reserve roads with names, tracks, and cartographic detail |

This is the **only** base layer. Do not substitute OSM or any remote tile source.

### Conversion to MBTiles (one-time, on Arch Linux)

```bash
# Install GDAL
sudo pacman -S gdal

# Verify the source file
gdalinfo kwandwe_road_map_2024.tif

# Convert to MBTiles
gdal_translate -of MBTiles kwandwe_road_map_2024.tif kwandwe_2024.mbtiles

# Add zoom levels for smooth rendering at all zoom levels
gdaladdo -r average kwandwe_2024.mbtiles 2 4 8 16
```

Alternative: QGIS → Processing → Generate XYZ Tiles (MBTiles), zoom levels 12–18, EPSG:4326.

### Bundling Strategy — Bundled Inside APK

The MBTiles file is placed in:

```
android/app/src/main/assets/tiles/kwandwe_2024.mbtiles
```

Gradle bundles it raw into the APK (Android native assets bypass Flutter's compression pipeline — no corruption of binary tile data).

On first app launch, `TileLoaderService` copies the file from the APK to device storage with a progress bar. Every subsequent launch reads directly from device storage — instant.

**APK size:** Sideloaded APKs have no size limit. A 50–150MB APK is perfectly fine for distribution via USB, WhatsApp, or direct link.

### Updating the Map

When a new cartographic version is produced:
1. Re-run GDAL conversion
2. Replace file in `android/app/src/main/assets/tiles/`
3. Call `TileLoaderService.clearExtractedTile()` on launch to force re-extraction
4. Rebuild and redistribute APK

---

## Folder Structure

```
kwandwe_map/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml        ← location + storage permissions
│       └── assets/tiles/
│           └── kwandwe_2024.mbtiles   ← MAP FILE GOES HERE (not in Flutter assets/)
├── lib/
│   ├── main.dart                      ← entry point, ProviderScope
│   ├── app.dart                       ← MaterialApp + theme
│   ├── core/
│   │   ├── theme.dart                 ← Kwandwe earth-tone colour palette
│   │   ├── constants.dart             ← map centre, zoom levels, file name
│   │   └── tile_loader_service.dart   ← extracts MBTiles from APK on first launch
│   ├── features/
│   │   ├── map/
│   │   │   ├── map_screen.dart        ← main map UI, loading screen, error screen
│   │   │   └── map_provider.dart      ← GPS tracking + tile load state (Riverpod)
│   │   ├── coordinates/
│   │   │   ├── coordinate_parser.dart ← parses decimal degrees + DMS formats
│   │   │   └── coordinate_input_sheet.dart ← paste-coordinate bottom sheet UI
│   │   └── pins/
│   │       └── pins_provider.dart     ← in-memory pin state (Riverpod)
│   └── models/
│       └── pin_model.dart             ← MapPin model, PinType enum, colours
├── assets/tiles/
│   └── README.md                      ← conversion instructions (no map file here)
├── plan.md                            ← this file
├── agent.md                           ← AI agent rules
├── pubspec.yaml                       ← dependencies
├── .gitignore                         ← excludes .mbtiles and .tif from git
└── README.md                          ← quick start guide
```

> V2 will add: `lib/features/auth/`, `lib/features/markers/`, `lib/features/dashboard/`, `supabase/schema.sql`, `supabase/rls_policies.sql`

---

## Versions

Complete V1 fully before starting V2. No Supabase, no auth, no database in V1.

---

## Version 1 — Offline Map & Coordinate Locator

**Goal:** Standalone app. No backend. No login. Open it, see the reserve map, see your GPS position, paste rhino collar coordinates to fly to the location, drop manual pins.

### V1 Phase 1 — Project Bootstrap ✅ COMPLETE
- Flutter project created (`kwandwe_map`)
- All V1 dependencies added to `pubspec.yaml`
- Riverpod ProviderScope wrapping app
- Earthy Kwandwe theme applied
- Folder structure established

### V1 Phase 2 — Map Core ✅ COMPLETE
- `TileLoaderService` — extracts MBTiles from APK to device storage on first launch
- Progress screen shown during first-launch extraction
- Error screen if MBTiles file missing from APK
- `MapProvider` — manages GPS tracking state + tile load status
- `MapScreen` — renders MbTilesLayer as base layer
- GPS blue dot with accuracy circle
- GPS recenter button

### V1 Phase 3 — Coordinate Locator ✅ COMPLETE
- `CoordinateParser` — parses decimal degrees (`-33.1234, 26.5678`) and DMS (`33°07'24.2"S 26°34'04.1"E`) automatically
- `CoordinateInputSheet` — bottom sheet with paste button, live validation, green confirmation
- Map animates to parsed coordinates
- Drops a Rhino Alert pin at location
- Format display shows parsed coordinates in readable form

### V1 Phase 4 — Manual Pin Drops ✅ COMPLETE
- Long-press anywhere on map → label dialog → drops pin
- Three pin types: Rhino Alert (red), Manual (brown), Waypoint (amber)
- Tap any pin → detail bottom sheet (label, type, coordinates, timestamp, delete)
- Clear all pins button in app bar
- All pins in-memory only (intentional — no persistence in V1)

### V1 Phase 5 — Polish & APK 🔲 TODO
- [ ] Add Kwandwe app icon (`assets/logo.png`)
- [ ] Handle location permission denied gracefully (show message, not crash)
- [ ] Handle location permission permanently denied (open settings)
- [ ] Test MBTiles extraction on real Android device
- [ ] Test coordinate parser with actual rhino collar alert formats
- [ ] `flutter build apk --release`
- [ ] Field test on reserve — confirm GPS accuracy and map alignment

---

## Version 1 Success Criteria

- [ ] App opens and shows Kwandwe reserve map fully offline
- [ ] Blue dot shows current GPS position accurately on the reserve map
- [ ] Paste rhino collar coordinates → map flies to location, drops pin
- [ ] Coordinate parser handles decimal degrees and DMS formats automatically
- [ ] Manual long-press pin drop works anywhere on the map
- [ ] Multiple pins can be active simultaneously
- [ ] Runs on Android with zero internet connection
- [ ] APK distributed and installed via sideload successfully

---

## Version 2 — Full Platform (Start Only After V1 Is Field-Tested)

**Goal:** Add Supabase backend, user auth, shared real-time markers, road condition reporting, and management dashboard.

### V2 Phase 1 — Supabase Setup
- Create Supabase project
- Implement schema: `profiles`, `markers` tables (see schema below)
- Configure RLS policies
- Supabase Auth — email/password, admin-only invite (no self-registration)
- Test in Supabase dashboard before touching Flutter

### V2 Phase 2 — Auth Integration
- Add `supabase_flutter` to `pubspec.yaml`
- Login screen with session persistence
- Admin account creation screen
- Role-based UI rendering (field worker vs management)

### V2 Phase 3 — Shared Markers & Real-time Sync
- Migrate V1 in-memory pins to Supabase `markers` table
- Road condition marker form (category, severity, photo)
- Supabase Realtime subscription — live marker updates across all devices
- Offline queue: sqflite local DB when no signal, sync on reconnect

### V2 Phase 4 — Management Dashboard
- All active markers with category/status/user filters
- Marker history and audit log (`resolved_by`, `resolved_at`)
- Export markers as CSV or GeoJSON

### V2 Phase 5 — Polish & Notifications
- Full Kwandwe branding
- Push notifications for critical road markers and rhino alerts
- Optional: Flutter Web build for desktop browser use

---

## V2 Database Schema (Supabase / PostgreSQL)

### `profiles` table
```sql
id          uuid references auth.users primary key
full_name   text not null
role        text check (role in ('field_worker', 'maintenance_tech', 'management', 'admin'))
avatar_url  text
created_at  timestamptz default now()
```

### `markers` table
```sql
id           uuid primary key default gen_random_uuid()
created_by   uuid references profiles(id)
lat          double precision not null
lng          double precision not null
title        text not null
description  text
category     text check (category in (
               'team_location', 'water_pump', 'solar_panel', 'vehicle', 'hazard', 'general',
               'road_closed_vegetation', 'road_closed_fallen_tree', 'road_damaged',
               'road_flooded', 'road_blocked_wildlife', 'road_maintenance'
             ))
road_name    text
severity     text check (severity in ('low', 'medium', 'high', 'critical'))
status       text check (status in ('active', 'resolved', 'pending')) default 'active'
resolved_by  uuid references profiles(id)
resolved_at  timestamptz
photo_url    text
is_offline   boolean default false
created_at   timestamptz default now()
updated_at   timestamptz default now()
```

### V2 Row Level Security Rules
- Field workers: SELECT/INSERT/UPDATE own markers only
- Maintenance techs: SELECT all, INSERT/UPDATE own
- Management: SELECT/UPDATE/DELETE all
- Admin: manage all profiles
- All authenticated: SELECT profiles (for name display)

---

## Road Condition Markers (V2)

### Categories

| Category | Icon | Description |
|---|---|---|
| `road_closed_vegetation` | 🌿 | Track overgrown, blocked by vegetation |
| `road_closed_fallen_tree` | 🪵 | Tree down across road |
| `road_damaged` | ⚠️ | Potholes, erosion, surface breakdown |
| `road_flooded` | 💧 | Water crossing or flooding |
| `road_blocked_wildlife` | 🐘 | Animals blocking road |
| `road_maintenance` | 🔧 | Scheduled or active maintenance |

### Severity & Map Display

| Severity | Meaning | Map Icon |
|---|---|---|
| `critical` | Road closed — do not attempt | 🔴 Red, pulsing |
| `high` | Not recommended — seek alternate route | 🔴 Red |
| `medium` | 4x4 only, reduce speed | 🟠 Orange |
| `low` | Passable with caution | 🟡 Yellow |
| resolved | Issue cleared | ⚫ Grey, hidden by default |

---

## Key Constraints (All Versions)

- Offline-first always — the reserve has no reliable cell signal
- No third-party map APIs that require paid keys or internet
- The Kwandwe MBTiles is the only base layer — never substitute OSM
- Flutter targets Android first, web second
- No self-registration — admin creates all V2 accounts
- Do not start V2 until V1 success criteria are all checked off

---

## V2 Success Criteria

- [ ] Field worker can log in and see their role-based view
- [ ] Shared road condition markers visible to all users in real time
- [ ] App works offline and syncs markers on reconnect
- [ ] Management can see all active team positions and markers
- [ ] Admin can create and manage user accounts
- [ ] Critical markers trigger push notifications
