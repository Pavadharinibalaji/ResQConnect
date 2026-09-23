import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/map/navigation_launcher.dart';

void main() {
  const lat = 12.9716;
  const lng = 77.5946;

  group('NavigationLauncher.buildCandidateUris', () {
    test('always offers at least one destination', () {
      final uris = NavigationLauncher.buildCandidateUris(lat: lat, lng: lng);
      expect(uris, isNotEmpty);
    });

    test('never calls a paid directions API', () {
      final uris = NavigationLauncher.buildCandidateUris(
        lat: lat,
        lng: lng,
        label: 'Structure fire',
      );

      for (final uri in uris) {
        final value = uri.toString().toLowerCase();
        expect(
          value,
          isNot(contains('googleapis.com')),
          reason: 'Directions must not hit a billed Google endpoint',
        );
        expect(value, isNot(contains('maps.googleapis')));
        expect(value, isNot(contains('api_key')));
        expect(value, isNot(contains('apikey')));
      }
    });

    test('falls back to keyless OpenStreetMap routing in a browser', () {
      final uris = NavigationLauncher.buildCandidateUris(lat: lat, lng: lng);

      final osmRoute = uris.firstWhere(
        (u) => u.host == 'www.openstreetmap.org' && u.path == '/directions',
        orElse: () => Uri.parse('about:blank'),
      );

      expect(osmRoute.scheme, 'https');
      expect(osmRoute.query, contains('$lat'));
      expect(osmRoute.query, contains('$lng'));
    });

    test('final fallback still pins the destination', () {
      final uris = NavigationLauncher.buildCandidateUris(lat: lat, lng: lng);
      final last = uris.last.toString();

      expect(last, contains('openstreetmap.org'));
      expect(last, contains('mlat=$lat'));
      expect(last, contains('mlon=$lng'));
    });

    test('carries the exact coordinates through every candidate', () {
      final uris = NavigationLauncher.buildCandidateUris(lat: lat, lng: lng);

      for (final uri in uris) {
        final decoded = Uri.decodeFull(uri.toString());
        expect(
          decoded,
          allOf(contains('$lat'), contains('$lng')),
          reason: '$uri lost the destination coordinates',
        );
      }
    });

    test('a label with spaces and parentheses stays URI-safe', () {
      final uris = NavigationLauncher.buildCandidateUris(
        lat: lat,
        lng: lng,
        label: 'Fire at Elm & 5th (2nd floor)',
      );

      // Uri.parse would have thrown above on a malformed candidate; assert the
      // set is still usable and unambiguous.
      expect(uris, isNotEmpty);
      for (final uri in uris) {
        expect(uri.hasScheme, isTrue);
      }
    });

    test('a blank label does not produce an empty parenthesis group', () {
      final uris = NavigationLauncher.buildCandidateUris(
        lat: lat,
        lng: lng,
        label: '   ',
      );

      for (final uri in uris) {
        expect(uri.toString(), isNot(contains('()')));
      }
    });
  });
}
