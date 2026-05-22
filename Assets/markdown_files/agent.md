# Agent Instructions — Kwandwe Powerhouse Map

## Purpose of This File

This file prevents AI hallucination, scope creep, and architectural drift. Every AI agent or coding assistant working in this project MUST read this file AND `plan.md` before writing any code, creating any file, or making any structural decision. If a task conflicts with these rules, stop and ask the developer before proceeding.

---

## Project Identity

| Field | Value |
|---|---|
| **App name** | Kwandwe Powerhouse Map |
| **Purpose** | Offline GPS map for Kwandwe Private Game Reserve — rhino collar coordinate lookup, manual pin drops, road condition reporting (V2) |
| **Platform** | Flutter → Android APK (sideloaded, no Play Store) |
| **Developer** | Solo developer, South Africa, Arch Linux |
| **Source of truth** | `plan.md` — read it before every task |
| **Current version** | V1 — Phases 1–4 complete. Phase 5 (Polish & APK) in progress |

---

## CRITICAL — Version Discipline

**V1 must be fully field-tested before V2 begins.**

### What V1 IS:
- Offline map loaded from bundled MBTiles file
- Live GPS blue dot
- Coordinate locator (paste rhino collar alerts)
- In-memory manual pin drops
- No backend. No login. No database. No internet required.

### What V1 is NOT and must never become:
- No Supabase — not even imports or pubspec entries
- No login screen, auth flow, or user concept
- No persistent storage of pins between sessions
- No shared markers or real-time anything
- No V2 folder scaffolding

If the developer asks for any of the above while V1 success criteria are incomplete — remind them of this rule and ask for explicit confirmation before proceeding.

---

## Non-Negotiable Rules

### 1. Read plan.md first — every time
Before writing any feature, file, or database change — read `plan.md`. Do not invent requirements. Do not assume scope. Do not add features not listed in the current active phase.

### 2. Never change the tech stack without explicit approval

**Approved V1 stack:**
- Flutter (Dart) — no React Native, no Kotlin-only, no Expo
- flutter_map — no Google Maps, no Mapbox (paywalls)
- flutter_map_mbtiles — no other tile renderer
- Riverpod — no BLoC, no Provider (legacy), no GetX
- geolocator — no alternative GPS packages
- MBTiles format — no XYZ tiles, no GeoJSON tiles, no WMS

**Approved V2 additions (not before):**
- supabase_flutter
- sqflite or Hive (offline queue only)

If a library has a bug that requires a swap, comment the issue in code and ask the developer. Never silently swap.

### 3. The map file is sacred
- Base layer is `kwandwe_2024.mbtiles` — Kwandwe's own cartographic map
- File lives at `android/app/src/main/assets/tiles/kwandwe_2024.mbtiles`
- Do NOT move it to Flutter's `assets/` folder — Flutter compresses assets and corrupts binary MBTiles
- Do NOT replace it with OpenStreetMap, Mapbox, or any remote tile URL
- OSM is never acceptable as a substitute — it does not contain reserve roads or names

### 4. MBTiles bundling approach is fixed
The tile file is bundled in Android native assets and extracted to device storage by `TileLoaderService` on first launch. This approach is intentional and must not be changed to:
- Flutter asset bundling (compresses binary files)
- Runtime download from URL (requires internet)
- ADB sideload (requires developer setup by end user)

### 5. No placeholder or mock data in production code
- No `TODO: replace with real data`
- No hardcoded fake coordinates or test tokens
- No mock GPS positions
- Test data goes in `/test` folder only

### 6. Offline-first is mandatory
The reserve has no reliable cell signal. Every feature must work without internet. In V2, every write operation must check connectivity and queue locally if offline.

### 7. No self-registration (V2)
- No "Sign Up" screen
- No open Supabase auth endpoints
- Admin creates all accounts via invite only

### 8. Schema changes require three-file updates (V2)
Any database change must update ALL THREE simultaneously:
1. `supabase/schema.sql`
2. `supabase/rls_policies.sql`
3. Schema section in `plan.md`

Do all three or do none.

---

## Coding Standards

### Dart / Flutter
- `const` constructors wherever possible
- `AsyncValue` from Riverpod for loading/error/data states — not raw booleans
- No `setState` in complex screens — use Riverpod providers
- File naming: `snake_case.dart` matching the class name
- One class per file
- All service logic in service classes — never call services directly from widgets
- Handle all error states explicitly — no silent catches, no empty catch blocks

### Map / GPS
- Always request and handle location permissions before accessing GPS
- Handle: permission denied, permanently denied, location service disabled
- GPS coordinates never stored in UI state directly — always through providers
- Tile path always from `getApplicationDocumentsDirectory()` — never hardcoded

### V2 Supabase Standards (when active)
- All Supabase calls through service classes in `/lib/features/<feature>/`
- Explicit column selects only — never `select('*')` in production
- Always handle Supabase errors — no silent catches
- Use `upsert` for offline sync merges, not blind `insert`
- Service role key is server-side only — never in Flutter client code

### V2 Environment Variables
```dart
// Access via --dart-define at build time
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```
Never hardcode. Never commit to git.

---

## Current File Map

Every file that exists and what it does:

| File | Purpose |
|---|---|
| `lib/main.dart` | Entry point, ProviderScope |
| `lib/app.dart` | MaterialApp, theme, home screen |
| `lib/core/theme.dart` | Kwandwe colour palette (earth tones) |
| `lib/core/constants.dart` | Reserve centre coords, zoom levels, tile file name |
| `lib/core/tile_loader_service.dart` | Extracts MBTiles from APK to device storage on first launch |
| `lib/features/map/map_screen.dart` | Main map UI, loading screen, error screen |
| `lib/features/map/map_provider.dart` | GPS tracking + tile load state (Riverpod Notifier) |
| `lib/features/coordinates/coordinate_parser.dart` | Parses decimal degrees and DMS coordinate strings |
| `lib/features/coordinates/coordinate_input_sheet.dart` | Paste-coordinate bottom sheet with live validation |
| `lib/features/pins/pins_provider.dart` | In-memory pin list (Riverpod Notifier) |
| `lib/models/pin_model.dart` | MapPin model, PinType enum, pin colours |
| `android/app/src/main/AndroidManifest.xml` | Location + storage permissions |
| `android/app/src/main/assets/tiles/` | WHERE THE MBTILES FILE GOES |
| `pubspec.yaml` | All dependencies |
| `.gitignore` | Excludes .mbtiles and .tif from git |

---

## What You Must Never Do

| Action | Why |
|---|---|
| Add Supabase to V1 | V1 is intentionally backend-free |
| Add login or auth to V1 | V1 has no user concept |
| Persist pins between V1 sessions | In-memory is intentional for V1 |
| Use Google Maps or Mapbox | Paywall |
| Replace Kwandwe MBTiles with OSM | OSM has no reserve roads or names |
| Put MBTiles in Flutter `assets/` | Flutter compresses it — corrupts binary |
| Hardcode tile paths | Use `getApplicationDocumentsDirectory()` |
| Use remote tile URLs as base layer | Requires internet — unacceptable |
| Parse only one coordinate format | Must handle decimal degrees AND DMS |
| Use `select('*')` in V2 production queries | Performance and security |
| Hardcode Supabase keys | Use `--dart-define` |
| Bypass RLS with service role key in Flutter | Security — server-side only |
| Skip offline queue for V2 writes | Reserve has no cell signal |
| Scaffold V2 files before V1 is field-tested | Premature complexity |
| Restructure folders without updating this file | Breaks agent context |

---

## When You Are Unsure

Stop. Do not guess. Surface the question to the developer.

Trigger this when:
- A requirement in `plan.md` seems contradictory
- A library requires swapping due to a bug
- A new feature request is not in any phase of `plan.md`
- A V2 schema change would break existing data
- The offline sync logic has an uncovered edge case
- The MBTiles file format behaves unexpectedly

---

## File Change Log

| Date | Change | Reason |
|---|---|---|
| Session 1 | Initial plan and agent created | Project start |
| Session 1 | Road condition markers added to schema | Reserve operations requirement |
| Session 1 | Versioning restructured — V1 standalone, V2 full platform | Keep V1 simple and shippable |
| Session 1 | Map bundling strategy decided — Android native assets | Prevents Flutter compression corrupting MBTiles |
| Session 1 | Full project folder and all V1 code scaffolded | Foundation complete |
| Session 1 | plan.md and agent.md fully updated to reflect built state | Sync docs with reality |
