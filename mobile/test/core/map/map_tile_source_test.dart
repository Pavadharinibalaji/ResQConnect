import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/map/map_tile_source.dart';

void main() {
  group('MapTileSource', () {
    test('every shipped source is keyless', () {
      for (final source in MapTileSource.all) {
        expect(
          source.requiresApiKey,
          isFalse,
          reason: '${source.name} must not require a billed API key',
        );
        expect(
          source.urlTemplate,
          isNot(contains('{apiKey}')),
          reason: '${source.name} URL must not interpolate a credential',
        );
        expect(
          source.urlTemplate,
          isNot(contains('key=')),
          reason: '${source.name} URL must not carry a key query parameter',
        );
      }
    });

    test('no shipped source points at a Google endpoint', () {
      for (final source in MapTileSource.all) {
        expect(source.urlTemplate.toLowerCase(), isNot(contains('google')));
      }
    });

    test('every source carries the attribution its licence requires', () {
      for (final source in MapTileSource.all) {
        expect(source.attributionText.trim(), isNotEmpty);
        expect(source.attributionUrl, startsWith('https://'));
        expect(source.licenseNote.trim(), isNotEmpty);
      }
    });

    test('OpenStreetMap source credits OSM contributors', () {
      expect(
        MapTileSource.openStreetMap.attributionText,
        contains('OpenStreetMap contributors'),
      );
      expect(
        MapTileSource.openStreetMap.attributionUrl,
        'https://www.openstreetmap.org/copyright',
      );
    });

    test('active defaults to OpenStreetMap when no override is compiled in', () {
      expect(MapTileSource.active.id, MapTileSource.openStreetMap.id);
    });

    test('zoom bounds are coherent', () {
      for (final source in MapTileSource.all) {
        expect(source.minZoom, lessThan(source.maxZoom));
        expect(source.maxNativeZoom, lessThanOrEqualTo(source.maxZoom));
      }
    });

    test('user agent identifies the app, as the OSM tile policy requires', () {
      expect(MapTileSource.userAgentPackageName, 'com.resqconnect.resqconnect');
    });
  });
}
