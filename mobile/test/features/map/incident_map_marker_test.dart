import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/features/map/presentation/widgets/incident_map_marker.dart';

void main() {
  group('IncidentMarkerStyle.forSeverity', () {
    test('maps each severity to its emergency colour', () {
      expect(
        IncidentMarkerStyle.forSeverity('critical').color,
        AppColors.severityCritical,
      );
      expect(
        IncidentMarkerStyle.forSeverity('high').color,
        AppColors.severityHigh,
      );
      expect(
        IncidentMarkerStyle.forSeverity('moderate').color,
        AppColors.severityModerate,
      );
      expect(
        IncidentMarkerStyle.forSeverity('low').color,
        AppColors.severityLow,
      );
    });

    test('treats the backend "medium" severity as moderate', () {
      // The API writes "medium"; the UI vocabulary is "moderate". Both must
      // resolve to the same pin rather than silently falling through to low.
      expect(
        IncidentMarkerStyle.forSeverity('medium').color,
        IncidentMarkerStyle.forSeverity('moderate').color,
      );
      expect(
        IncidentMarkerStyle.forSeverity('medium').rank,
        IncidentMarkerStyle.forSeverity('moderate').rank,
      );
    });

    test('is case insensitive', () {
      expect(
        IncidentMarkerStyle.forSeverity('CRITICAL').rank,
        IncidentMarkerStyle.forSeverity('critical').rank,
      );
    });

    test('ranks severities so critical pins draw on top', () {
      final critical = IncidentMarkerStyle.forSeverity('critical').rank;
      final high = IncidentMarkerStyle.forSeverity('high').rank;
      final moderate = IncidentMarkerStyle.forSeverity('moderate').rank;
      final low = IncidentMarkerStyle.forSeverity('low').rank;

      expect(critical, greaterThan(high));
      expect(high, greaterThan(moderate));
      expect(moderate, greaterThan(low));
    });

    test('unknown severity degrades to the low-severity style', () {
      final unknown = IncidentMarkerStyle.forSeverity('not-a-severity');
      expect(unknown.color, AppColors.severityLow);
      expect(unknown.rank, 1);
    });
  });

  group('IncidentMapMarker widget', () {
    testWidgets('reports taps so the incident sheet can open', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 38,
                height: 48,
                child: IncidentMapMarker(
                  severity: 'critical',
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IncidentMapMarker));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('exposes a semantic label for screen readers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 38,
                height: 48,
                child: IncidentMapMarker(
                  severity: 'high',
                  semanticLabel: 'high incident: Gas leak',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('high incident: Gas leak'), findsOneWidget);
    });
  });

  group('UserLocationMarker', () {
    testWidgets('animates without leaking its ticker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 46,
                height: 46,
                child: UserLocationMarker(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UserLocationMarker), findsOneWidget);

      // Replacing the tree disposes the repeating controller; a leaked ticker
      // would fail the test here.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
    });

    testWidgets('renders a muted dot when the fix is stale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 46,
                height: 46,
                child: UserLocationMarker(isStale: true),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Approximate location'), findsOneWidget);
    });
  });
}
