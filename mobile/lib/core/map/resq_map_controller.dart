import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Camera facade the ResQConnect UI programs against.
///
/// Pages hold a [ResQMapController] and call [moveTo] / [fitCoordinates]; they
/// never touch the underlying map package. `flutter_map`'s own `MapController`
/// only supports instant jumps, so the smooth transitions responders expect are
/// implemented here rather than by pulling in another dependency.
///
/// Swapping map providers means reimplementing this class — not rewriting every
/// caller.
class ResQMapController {
  MapController? _map;
  TickerProvider? _vsync;

  /// Tears down the in-flight camera animation exactly once. Null when idle.
  VoidCallback? _releaseAnimation;

  /// Whether a map widget is currently bound. Calls made while detached are
  /// silently ignored, which keeps callers free of null checks.
  bool get isAttached => _map != null;

  /// Current camera centre, or null when detached.
  LatLng? get center => _map?.camera.center;

  /// Current camera zoom, or null when detached.
  double? get zoom => _map?.camera.zoom;

  /// Called by [ResQMapView] once the underlying map exists.
  void attach(MapController map, TickerProvider vsync) {
    _map = map;
    _vsync = vsync;
  }

  /// Called by [ResQMapView] on dispose.
  void detach() {
    _cancelRunningAnimation();
    _map = null;
    _vsync = null;
  }

  void _cancelRunningAnimation() {
    final release = _releaseAnimation;
    _releaseAnimation = null;
    release?.call();
  }

  /// Moves the camera to [destination], optionally animating.
  ///
  /// [zoomLevel] defaults to the current zoom so "recentre" does not also
  /// change the zoom the user had chosen.
  void moveTo(
    LatLng destination, {
    double? zoomLevel,
    bool animate = true,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOutCubic,
  }) {
    final map = _map;
    final vsync = _vsync;
    if (map == null) return;

    final targetZoom = zoomLevel ?? map.camera.zoom;

    if (!animate || vsync == null) {
      map.move(destination, targetZoom);
      return;
    }

    _cancelRunningAnimation();

    final startCenter = map.camera.center;
    final startZoom = map.camera.zoom;

    // Nothing to animate — avoids a pointless controller and a visible stall.
    if (_isSameCamera(startCenter, destination, startZoom, targetZoom)) {
      return;
    }

    final controller = AnimationController(vsync: vsync, duration: duration);
    final latLngTween = LatLngTween(begin: startCenter, end: destination);
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);
    final animation = CurvedAnimation(parent: controller, curve: curve);

    void tick() {
      // The map can be torn down mid-flight (navigation, tab switch).
      final map = _map;
      if (map == null) return;
      map.move(latLngTween.evaluate(animation), zoomTween.evaluate(animation));
    }

    // Guarded so that a natural finish, a superseding move and detach() can all
    // request teardown without risking a double dispose.
    var released = false;
    void release() {
      if (released) return;
      released = true;
      controller.removeListener(tick);
      animation.dispose();
      controller.dispose();
    }

    _releaseAnimation = release;
    controller.addListener(tick);

    controller.forward().whenCompleteOrCancel(() {
      if (identical(_releaseAnimation, release)) {
        _releaseAnimation = null;
      }
      release();
    });
  }

  /// Frames every coordinate in [points] with [padding] breathing room.
  ///
  /// A single point (or several that coincide) has no meaningful bounds, so it
  /// falls back to a plain centred move at [singlePointZoom].
  void fitCoordinates(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(64),
    double maxZoom = 16.0,
    double singlePointZoom = 15.0,
  }) {
    final map = _map;
    if (map == null || points.isEmpty) return;

    _cancelRunningAnimation();

    if (points.length == 1 || _allCoincident(points)) {
      moveTo(points.first, zoomLevel: singlePointZoom);
      return;
    }

    map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: padding,
        maxZoom: maxZoom,
      ),
    );
  }

  static bool _allCoincident(List<LatLng> points) {
    final first = points.first;
    const epsilon = 1e-7;
    for (final p in points) {
      if ((p.latitude - first.latitude).abs() > epsilon ||
          (p.longitude - first.longitude).abs() > epsilon) {
        return false;
      }
    }
    return true;
  }

  static bool _isSameCamera(
    LatLng a,
    LatLng b,
    double zoomA,
    double zoomB,
  ) {
    const coordEpsilon = 1e-6;
    const zoomEpsilon = 1e-3;
    return (a.latitude - b.latitude).abs() < coordEpsilon &&
        (a.longitude - b.longitude).abs() < coordEpsilon &&
        (zoomA - zoomB).abs() < zoomEpsilon;
  }
}
