import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/core/map/map_tile_source.dart';
import 'package:resqconnect/core/map/resq_map_controller.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

/// The single map surface used across ResQConnect.
///
/// Wraps `flutter_map` so that tile sourcing, offline/failure handling and the
/// provider's required attribution are implemented once. Feature pages supply
/// markers and camera intent; they never import the map package directly, which
/// is what makes a future provider swap a change to this file alone.
class ResQMapView extends StatefulWidget {
  const ResQMapView({
    super.key,
    required this.controller,
    required this.initialCenter,
    this.initialZoom = 13.5,
    this.markers = const <Marker>[],
    this.circles = const <CircleMarker>[],
    this.onTap,
    this.onLongPress,
    this.onMapReady,
    this.interactive = true,
    this.interactionFlags,
    this.showAttribution = true,
    this.tileSource,
    this.attributionAlignment = AttributionAlignment.bottomRight,
  });

  final ResQMapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final List<CircleMarker> circles;

  /// Fired when the user taps empty map (not a marker).
  final void Function(LatLng point)? onTap;

  /// Fired on long-press — used by the incident location picker.
  final void Function(LatLng point)? onLongPress;

  final VoidCallback? onMapReady;

  /// When false the map is a static preview (no pan/zoom gestures).
  final bool interactive;

  /// Overrides the gesture set while [interactive] is true.
  ///
  /// Use [ResQMapView.embeddedGestures] for a map inside a scrolling form, so
  /// one-finger drags still scroll the page.
  final int? interactionFlags;

  /// Attribution is a licence obligation for OSM tiles. Only disable it when
  /// the surrounding UI renders [MapAttributionBar] itself.
  final bool showAttribution;

  /// Defaults to [MapTileSource.active].
  final MapTileSource? tileSource;

  final AttributionAlignment attributionAlignment;

  /// Full-screen map gestures. Rotation stays off: a rotated map makes
  /// compass-free navigation to an incident harder to read.
  static const int fullScreenGestures =
      InteractiveFlag.all & ~InteractiveFlag.rotate;

  /// Gestures for a map embedded in a scrolling page.
  ///
  /// One-finger drag is deliberately excluded so the surrounding scroll view
  /// keeps it; the map is still pannable with two fingers and zoomable by
  /// pinch or double-tap, and taps still register.
  static const int embeddedGestures = InteractiveFlag.pinchZoom |
      InteractiveFlag.pinchMove |
      InteractiveFlag.doubleTapZoom |
      InteractiveFlag.scrollWheelZoom;

  @override
  State<ResQMapView> createState() => _ResQMapViewState();
}

class _ResQMapViewState extends State<ResQMapView>
    with TickerProviderStateMixin {
  late final MapController _mapController = MapController();

  /// Bumped on retry so the [TileLayer] is rebuilt and refetches failed tiles.
  int _tileEpoch = 0;

  int _tileErrorCount = 0;
  bool _tilesUnavailable = false;
  Timer? _tileErrorDebounce;

  MapTileSource get _source => widget.tileSource ?? MapTileSource.active;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_mapController, this);
  }

  @override
  void didUpdateWidget(covariant ResQMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      widget.controller.attach(_mapController, this);
    }
  }

  @override
  void dispose() {
    _tileErrorDebounce?.cancel();
    widget.controller.detach();
    _mapController.dispose();
    super.dispose();
  }

  /// Tile errors arrive during layout/paint, so state changes are deferred and
  /// debounced — a brief network blip should not flash a banner.
  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    _tileErrorCount++;
    if (_tilesUnavailable) return;

    _tileErrorDebounce?.cancel();
    _tileErrorDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      // A handful of failures is normal at tile boundaries; a sustained burst
      // is what indicates the provider or the connection is actually down.
      if (_tileErrorCount >= 3) {
        AppLogger.warning(
          'Map tiles failing from ${_source.name} '
          '($_tileErrorCount errors): $error',
        );
        setState(() => _tilesUnavailable = true);
      } else {
        // Isolated failures must not accumulate across a long session into a
        // spurious banner, so the burst counter resets once things go quiet.
        _tileErrorCount = 0;
      }
    });
  }

  void _retryTiles() {
    setState(() {
      _tileEpoch++;
      _tileErrorCount = 0;
      _tilesUnavailable = false;
    });
  }

  Future<void> _openAttributionUrl() async {
    final uri = Uri.parse(_source.attributionUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.warning('Could not open map licence page: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: _source.minZoom.toDouble(),
            maxZoom: _source.maxZoom.toDouble(),
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightBorder,
            onMapReady: widget.onMapReady,
            onTap: widget.onTap == null
                ? null
                : (_, point) => widget.onTap!(point),
            onLongPress: widget.onLongPress == null
                ? null
                : (_, point) => widget.onLongPress!(point),
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? (widget.interactionFlags ??
                      ResQMapView.fullScreenGestures)
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              key: ValueKey('tiles_${_source.id}_$_tileEpoch'),
              urlTemplate: _source.urlTemplate,
              subdomains: _source.subdomains,
              maxNativeZoom: _source.maxNativeZoom,
              maxZoom: _source.maxZoom.toDouble(),
              minZoom: _source.minZoom.toDouble(),
              // Required by the OSM tile usage policy: identify the app.
              userAgentPackageName: MapTileSource.userAgentPackageName,
              errorTileCallback: _onTileError,
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
              tileDisplay: const TileDisplay.fadeIn(
                duration: Duration(milliseconds: 180),
              ),
            ),
            if (widget.circles.isNotEmpty) CircleLayer(circles: widget.circles),
            if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
            if (widget.showAttribution)
              RichAttributionWidget(
                alignment: widget.attributionAlignment,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    _source.attributionText,
                    prependCopyright: false,
                    onTap: _openAttributionUrl,
                  ),
                ],
              ),
          ],
        ),

        if (_tilesUnavailable)
          Positioned(
            left: AppTheme.spaceM,
            right: AppTheme.spaceM,
            top: AppTheme.spaceM,
            child: _TileFailureBanner(onRetry: _retryTiles),
          ),
      ],
    );
  }
}

/// Shown when map tiles cannot be fetched.
///
/// Deliberately non-blocking: markers, the incident list and every responder
/// action stay usable on the blank canvas, because losing basemap imagery must
/// not take the emergency workflow down with it.
class _TileFailureBanner extends StatelessWidget {
  const _TileFailureBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.warmSignalAmber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Map imagery unavailable',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Incident locations are still accurate.',
                    style: AppTheme.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryEmergencyRed,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone attribution line for surfaces that render a map without the
/// built-in overlay (for example a fixed-height preview card).
///
/// Displaying the tile provider's attribution is a licence requirement, not a
/// nicety — see [MapTileSource.licenseNote].
class MapAttributionBar extends StatelessWidget {
  const MapAttributionBar({super.key, this.tileSource});

  final MapTileSource? tileSource;

  @override
  Widget build(BuildContext context) {
    final source = tileSource ?? MapTileSource.active;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse(source.attributionUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          AppLogger.warning('Could not open map licence page: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Colors.black.withValues(alpha: 0.45),
        child: Text(
          source.attributionText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}
