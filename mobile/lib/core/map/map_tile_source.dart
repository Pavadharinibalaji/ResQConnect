/// Provider-agnostic description of a raster map tile source.
///
/// ResQConnect deliberately avoids map providers that require a billed API key.
/// Every value a map widget needs in order to render tiles and satisfy the
/// provider's licensing terms lives here, so swapping providers later is a
/// one-line change in [MapTileSource.active] rather than a UI rewrite.
class MapTileSource {
  const MapTileSource({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.attributionText,
    required this.attributionUrl,
    this.subdomains = const <String>[],
    this.minZoom = 2,
    this.maxZoom = 19,
    this.maxNativeZoom = 19,
    this.requiresApiKey = false,
    this.licenseNote = '',
  });

  /// Stable identifier, useful for tile cache namespacing and analytics.
  final String id;

  /// Human readable provider name, shown in the attribution UI.
  final String name;

  /// Slippy-map URL template, e.g. `https://tile.example.org/{z}/{x}/{y}.png`.
  final String urlTemplate;

  /// Attribution line the provider's licence requires to be visible on the map.
  final String attributionText;

  /// Destination opened when the user taps the attribution line.
  final String attributionUrl;

  /// Optional `{s}` subdomains. Empty when the provider does not use them.
  final List<String> subdomains;

  /// Lowest zoom the UI should allow.
  final int minZoom;

  /// Highest zoom the UI should allow (may exceed [maxNativeZoom] via upscaling).
  final int maxZoom;

  /// Highest zoom for which the provider actually serves tiles.
  final int maxNativeZoom;

  /// Whether this source needs a paid/keyed credential. Kept false for the
  /// sources ResQConnect ships with; used to fail loudly if that ever changes.
  final bool requiresApiKey;

  /// Short human-readable summary of the provider's usage terms.
  final String licenseNote;

  /// OpenStreetMap standard raster tiles. Keyless and free to use within the
  /// OSMF Tile Usage Policy: attribution is mandatory, and a descriptive
  /// User-Agent identifying the app must be sent with every tile request.
  ///
  /// See https://operations.osmfoundation.org/policies/tiles/
  static const MapTileSource openStreetMap = MapTileSource(
    id: 'osm_standard',
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attributionText: '© OpenStreetMap contributors',
    attributionUrl: 'https://www.openstreetmap.org/copyright',
    maxNativeZoom: 19,
    maxZoom: 19,
    licenseNote:
        'Map data © OpenStreetMap contributors, available under the Open '
        'Database Licence (ODbL). Tiles served by the OSM Foundation under '
        'the OSMF Tile Usage Policy.',
  );

  /// OpenTopoMap — keyless terrain tiles, kept as a secondary option so the
  /// provider abstraction has more than one real implementation.
  static const MapTileSource openTopoMap = MapTileSource(
    id: 'opentopomap',
    name: 'OpenTopoMap',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    attributionText: '© OpenStreetMap contributors, SRTM | © OpenTopoMap (CC-BY-SA)',
    attributionUrl: 'https://opentopomap.org/about',
    maxNativeZoom: 17,
    maxZoom: 17,
    licenseNote:
        'Map data © OpenStreetMap contributors (ODbL). Tile rendering © '
        'OpenTopoMap, licensed CC-BY-SA 3.0.',
  );

  /// All sources the app knows about.
  static const List<MapTileSource> all = <MapTileSource>[
    openStreetMap,
    openTopoMap,
  ];

  /// The source the app renders with.
  ///
  /// Override at build time with:
  /// `flutter run --dart-define=MAP_TILE_SOURCE=opentopomap`
  static MapTileSource get active {
    const requestedId = String.fromEnvironment(
      'MAP_TILE_SOURCE',
      defaultValue: 'osm_standard',
    );
    for (final source in all) {
      if (source.id == requestedId) return source;
    }
    return openStreetMap;
  }

  /// Sent as the tile request User-Agent. The OSM tile policy requires a value
  /// that identifies the application rather than a generic HTTP client.
  static const String userAgentPackageName = 'com.resqconnect.resqconnect';
}
