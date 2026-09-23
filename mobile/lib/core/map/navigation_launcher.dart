import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import 'package:resqconnect/core/logger/app_logger.dart';

/// Outcome of a turn-by-turn navigation request.
enum NavigationLaunchResult {
  /// An external maps/navigation app (or browser) accepted the destination.
  launched,

  /// No installed handler could open the destination.
  noHandler,

  /// A handler was found but threw while launching.
  failed,
}

/// Opens turn-by-turn navigation to a coordinate in whatever maps application
/// the user already has.
///
/// ResQConnect does not call a paid directions API. Routing is delegated to the
/// device's own navigation app via platform URI schemes, falling back to a
/// browser-based OpenStreetMap route. That keeps directions keyless and lets
/// responders use the navigation app they trust.
class NavigationLauncher {
  const NavigationLauncher._();

  /// Builds the ordered list of destination URIs to try for [lat]/[lng].
  ///
  /// Ordering matters: platform-native schemes first (they hand off to an
  /// installed navigation app), then vendor-neutral web routing.
  static List<Uri> buildCandidateUris({
    required double lat,
    required double lng,
    String? label,
  }) {
    final encodedLabel = label == null || label.trim().isEmpty
        ? null
        : Uri.encodeComponent(label.trim());

    final candidates = <Uri>[];

    if (!kIsWeb && Platform.isAndroid) {
      // RFC 5870-style geo URI. Every Android maps app registers for this, so
      // the user picks their own (OsmAnd, Organic Maps, Google Maps, ...).
      candidates.add(
        Uri.parse(
          encodedLabel == null
              ? 'geo:$lat,$lng?q=$lat,$lng'
              : 'geo:$lat,$lng?q=$lat,$lng($encodedLabel)',
        ),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      // Apple Maps ships on every iOS device and needs no API key.
      candidates.add(
        Uri.parse('maps://?daddr=$lat,$lng&dirflg=d'),
      );
      candidates.add(
        Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'),
      );
    }

    // Vendor-neutral browser fallback: OpenStreetMap's routing engine (OSRM).
    candidates.add(
      Uri.parse(
        'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car'
        '&route=%3B$lat%2C$lng',
      ),
    );

    // Last resort: show the destination pin even if routing is unavailable.
    candidates.add(
      Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng'),
    );

    return candidates;
  }

  /// Attempts each candidate URI in order until one launches.
  static Future<NavigationLaunchResult> launchDirections({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final candidates = buildCandidateUris(lat: lat, lng: lng, label: label);

    var sawHandlerError = false;

    for (final uri in candidates) {
      try {
        if (!await canLaunchUrl(uri)) continue;

        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          AppLogger.info('Navigation handed off to ${uri.scheme}: $uri');
          return NavigationLaunchResult.launched;
        }
        sawHandlerError = true;
      } catch (e) {
        sawHandlerError = true;
        AppLogger.warning('Navigation launch failed for $uri: $e');
      }
    }

    return sawHandlerError
        ? NavigationLaunchResult.failed
        : NavigationLaunchResult.noHandler;
  }
}
