# Mapping & Navigation

ResQConnect renders maps with **`flutter_map`** over **OpenStreetMap** raster tiles.
There is **no Google Maps dependency and no map API key anywhere in the project** —
neither the mobile app nor the backend requires a billing account to display maps
or to offer directions.

---

## Why not Google Maps

`google_maps_flutter` requires a Google Cloud API key backed by an enabled billing
account. Without one the map surface renders blank, which silently breaks incident
discovery — the core of the product. `flutter_map` + OSM removes that dependency
entirely.

The backend has never referenced Google Maps and still does not. It stores plain
`latitude` / `longitude` columns plus a PostGIS `location` geometry, all of which
are provider-neutral.

---

## Architecture

Feature pages never import `flutter_map` for anything but marker/circle value
types. All map behaviour funnels through three provider-agnostic pieces:

| File | Responsibility |
| --- | --- |
| `lib/core/map/map_tile_source.dart` | Declares tile providers: URL template, zoom range, attribution text/URL, licence note. |
| `lib/core/map/resq_map_controller.dart` | Camera facade — `moveTo`, `fitCoordinates`. Adds the smooth animation `flutter_map`'s `MapController` lacks. |
| `lib/features/map/presentation/widgets/resq_map_view.dart` | The one map widget. Owns tile sourcing, tile-failure UI and attribution. |

Supporting pieces:

| File | Responsibility |
| --- | --- |
| `lib/features/map/presentation/widgets/incident_map_marker.dart` | Severity-coded incident pin + pulsing GPS dot. |
| `lib/core/map/navigation_launcher.dart` | "Get directions" — hands a coordinate to an external maps app. |

### Swapping providers later

Add a `MapTileSource` constant and select it at build time:

```bash
flutter run --dart-define=MAP_TILE_SOURCE=opentopomap
```

If a future provider needs a key, set `requiresApiKey: true` and thread the
credential through `MapTileSource`. **No feature page needs to change** — only
`ResQMapView` reads the tile source.

---

## Licensing & attribution (required)

### OpenStreetMap (default, `osm_standard`)

- **Map data**: © OpenStreetMap contributors, licensed under the
  [Open Database Licence (ODbL)](https://www.openstreetmap.org/copyright).
- **Attribution is mandatory.** Every map surface displays
  `© OpenStreetMap contributors`, linking to the copyright page:
  - Full-screen maps use `flutter_map`'s `RichAttributionWidget`.
  - Fixed-height preview cards use `MapAttributionBar`.
  - **Do not remove these.** Passing `showAttribution: false` is only permitted
    when the surrounding widget renders `MapAttributionBar` itself.
- **Tile usage policy**: tiles come from the OSM Foundation's servers under the
  [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).
  The app sends `User-Agent: flutter_map (com.resqconnect.resqconnect)` as the
  policy requires.

### ⚠️ Production scale warning

The OSMF tile servers are **run on donated resources and are not intended to
serve a large production app**. They are appropriate for development, testing and
small deployments. Before a wide public launch, switch to one of:

- a self-hosted tile server (e.g. Tileserver GL with OpenMapTiles), or
- a paid OSM tile host (Thunderforest, MapTiler, Stadia Maps, Geoapify) — most
  have free tiers far more permissive than Google's, or
- offline/bundled vector tiles for the operating region.

Each is a `MapTileSource` entry plus (if keyed) a credential — not a code rewrite.
`flutter_map` prints a runtime warning about this on every startup; that warning
is expected and is the reason this section exists.

### OpenTopoMap (`opentopomap`)

Map data © OpenStreetMap contributors (ODbL); tile rendering © OpenTopoMap,
licensed **CC-BY-SA 3.0**. Attribution is likewise mandatory.

---

## Directions

`NavigationLauncher` does **not** call a routing API. It hands the destination
coordinate to whatever the device already has, in order:

1. **Android** — `geo:<lat>,<lng>?q=<lat>,<lng>(<label>)`. Every maps app
   registers for this, so the responder picks their own (Organic Maps, OsmAnd,
   Google Maps if installed, …).
2. **iOS** — `maps://?daddr=…`, then `https://maps.apple.com/?daddr=…`.
   Apple Maps ships on every device and needs no key.
3. **Any platform** — OpenStreetMap browser routing via the FOSSGIS OSRM engine.
4. **Last resort** — an OSM pin at the destination.

If nothing handles the request, the UI surfaces the raw coordinates with a
copy-to-clipboard action so a responder is never left without the location.

Android requires the `geo` scheme in `<queries>` for `canLaunchUrl` to succeed
under package visibility; this is already declared in `AndroidManifest.xml`.

---

## Failure handling

Tiles are network resources and responders work in degraded conditions.

- `ResQMapView` counts tile errors and, after a short debounce (≥3 sustained
  failures), shows a non-blocking "Map imagery unavailable" banner with a
  **RETRY** action that refetches the failed tiles.
- The banner is deliberately **non-blocking**: markers, the incident list,
  respond/withdraw and directions all keep working on a blank canvas. Losing
  basemap imagery must never take the emergency workflow down with it.
- A brief blip does not flash the banner; the debounce absorbs it.

---

## Platform configuration

**Android** — nothing map-specific to configure. No
`com.google.android.geo.API_KEY` meta-data, no Play Services Maps dependency.
Only `INTERNET` permission is needed, which is already present.

**iOS** — nothing to configure. The project never called
`GMSServices.provideAPIKey`.

### Android toolchain baseline

Unrelated to mapping, but required for the Android build to run at all with
Flutter 3.47.5:

| Component | Version | Why |
| --- | --- | --- |
| Android Gradle Plugin | **8.13.0** | Flutter 3.47.5 hard-requires AGP ≥ 8.11.1. |
| Gradle wrapper | **9.1.0** | AGP 8.13 needs Gradle 9.x; Gradle ≥ 9.1 is also the first release supporting JDK 25. |
| JDK | 25 (or 17–23 with Gradle 8.11.1 + AGP 8.11.1) | — |

`android/local.properties` is machine-local and gitignored — each developer
points `sdk.dir` / `flutter.sdk` at their own installs.

If a build fails with a path under a *different* user account
(`C:\Users\<someone-else>\...`), it is a stale incremental cache from another
machine. Run `flutter clean`.

**Verified on 2026-09-21**: `flutter analyze` clean, 36/36 tests pass, and
`flutter build apk --debug` produces an APK containing **zero** Google Maps
classes and no `geo.API_KEY` meta-data.
