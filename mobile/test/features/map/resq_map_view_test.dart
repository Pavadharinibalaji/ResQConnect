import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:resqconnect/core/map/map_tile_source.dart';
import 'package:resqconnect/core/map/resq_map_controller.dart';
import 'package:resqconnect/features/map/presentation/widgets/resq_map_view.dart';

/// Pumps [child] inside a sized, themed scaffold.
///
/// flutter_map needs finite constraints, so every map test goes through here.
Future<void> _pumpMap(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 600, child: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late ResQMapController controller;

  setUp(() => controller = ResQMapController());

  testWidgets('renders a flutter_map surface with an OSM tile layer',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, MapTileSource.openStreetMap.urlTemplate);
    expect(tileLayer.urlTemplate, isNot(contains('google')));
  });

  testWidgets('shows the tile provider attribution required by its licence',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
      ),
    );

    expect(
      find.textContaining('OpenStreetMap contributors'),
      findsOneWidget,
    );
  });

  testWidgets('binds the controller once the map is built', (tester) async {
    expect(controller.isAttached, isFalse);

    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        initialZoom: 13.0,
      ),
    );

    expect(controller.isAttached, isTrue);
    expect(controller.center?.latitude, closeTo(12.9716, 0.0001));
    expect(controller.zoom, closeTo(13.0, 0.0001));
  });

  testWidgets('moveTo repositions the camera', (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        initialZoom: 13.0,
      ),
    );

    controller.moveTo(const LatLng(19.0760, 72.8777), zoomLevel: 15.0);
    await tester.pumpAndSettle();

    expect(controller.center?.latitude, closeTo(19.0760, 0.01));
    expect(controller.center?.longitude, closeTo(72.8777, 0.01));
    expect(controller.zoom, closeTo(15.0, 0.01));
  });

  testWidgets('moveTo keeps the current zoom when none is given',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        initialZoom: 12.0,
      ),
    );

    controller.moveTo(const LatLng(13.0, 77.6));
    await tester.pumpAndSettle();

    expect(controller.zoom, closeTo(12.0, 0.01));
  });

  testWidgets('fitCoordinates frames every incident', (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        initialZoom: 16.0,
      ),
    );

    controller.fitCoordinates(
      const [
        LatLng(12.90, 77.50),
        LatLng(13.05, 77.70),
      ],
      padding: const EdgeInsets.all(24),
    );
    await tester.pumpAndSettle();

    // Framing two distant points must zoom out from the initial close-in view.
    expect(controller.zoom, lessThan(16.0));
    expect(controller.center?.latitude, closeTo(12.975, 0.05));
  });

  testWidgets('fitCoordinates on coincident points centres instead of zooming '
      'to infinity', (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(0, 0),
        initialZoom: 3.0,
      ),
    );

    controller.fitCoordinates(
      const [LatLng(12.9716, 77.5946), LatLng(12.9716, 77.5946)],
    );
    await tester.pumpAndSettle();

    expect(controller.center?.latitude, closeTo(12.9716, 0.01));
    expect(controller.zoom, closeTo(15.0, 0.01));
    expect(controller.zoom, lessThan(25.0));
  });

  testWidgets('renders incident markers passed by the page', (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        markers: [
          Marker(
            point: const LatLng(12.9716, 77.5946),
            width: 38,
            height: 48,
            child: const ColoredBox(color: Colors.red),
          ),
        ],
      ),
    );

    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  testWidgets('non-interactive preview disables map gestures', (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        interactive: false,
      ),
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags, InteractiveFlag.none);
  });

  testWidgets('embedded gestures leave one-finger drag to the parent scroll',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        interactionFlags: ResQMapView.embeddedGestures,
      ),
    );

    final flags =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options
            .interactionOptions
            .flags;

    // Without this, a map inside the create-incident form would swallow the
    // page scroll and strand the reporter mid-form.
    expect(flags & InteractiveFlag.drag, 0);
    expect(flags & InteractiveFlag.pinchZoom, isNot(0));
    expect(flags & InteractiveFlag.pinchMove, isNot(0));
  });

  testWidgets('full-screen gestures allow drag but never rotation',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
      ),
    );

    final flags =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options
            .interactionOptions
            .flags;

    expect(flags & InteractiveFlag.drag, isNot(0));
    expect(flags & InteractiveFlag.rotate, 0);
  });

  testWidgets('reports taps so the location picker can move its pin',
      (tester) async {
    LatLng? tapped;

    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
        onTap: (point) => tapped = point,
      ),
    );

    await tester.tapAt(const Offset(200, 300));
    // flutter_map holds a single tap for 250ms to rule out a double tap, so the
    // callback lands on a timer that pumpAndSettle alone will not advance.
    await tester.pump(const Duration(milliseconds: 400));

    expect(tapped, isNotNull);
    expect(tapped!.latitude, closeTo(12.9716, 1.0));
  });

  testWidgets('detaches the controller when the map is disposed',
      (tester) async {
    await _pumpMap(
      tester,
      ResQMapView(
        controller: controller,
        initialCenter: const LatLng(12.9716, 77.5946),
      ),
    );
    expect(controller.isAttached, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(controller.isAttached, isFalse);
    // Calls made after teardown must be inert rather than throwing.
    controller.moveTo(const LatLng(1, 1));
  });
}
