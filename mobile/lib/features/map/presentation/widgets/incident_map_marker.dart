import 'package:flutter/material.dart';

import 'package:resqconnect/core/theme/app_colors.dart';

/// Visual style for an incident pin, derived from the incident's severity.
///
/// Kept separate from any map SDK so the same styling drives markers, legends
/// and list rows regardless of which map provider renders them.
class IncidentMarkerStyle {
  const IncidentMarkerStyle({
    required this.color,
    required this.icon,
    required this.label,
    required this.rank,
  });

  final Color color;
  final IconData icon;
  final String label;

  /// Higher means more urgent. Used to paint critical pins on top.
  final int rank;

  static IncidentMarkerStyle forSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const IncidentMarkerStyle(
          color: AppColors.severityCritical,
          icon: Icons.priority_high_rounded,
          label: 'Critical',
          rank: 4,
        );
      case 'high':
        return const IncidentMarkerStyle(
          color: AppColors.severityHigh,
          icon: Icons.warning_amber_rounded,
          label: 'High',
          rank: 3,
        );
      case 'moderate':
      case 'medium':
        return const IncidentMarkerStyle(
          color: AppColors.severityModerate,
          icon: Icons.error_outline_rounded,
          label: 'Moderate',
          rank: 2,
        );
      default:
        return const IncidentMarkerStyle(
          color: AppColors.severityLow,
          icon: Icons.info_outline_rounded,
          label: 'Low',
          rank: 1,
        );
    }
  }
}

/// Teardrop pin used for emergency incidents on the map.
///
/// The widget is sized by the caller via `Marker.width`/`Marker.height`; the
/// pin tip sits at the bottom-centre so the marker should be anchored with
/// `Alignment.topCenter`.
class IncidentMapMarker extends StatelessWidget {
  const IncidentMapMarker({
    super.key,
    required this.severity,
    required this.onTap,
    this.isSelected = false,
    this.semanticLabel,
  });

  final String severity;
  final VoidCallback onTap;
  final bool isSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = IncidentMarkerStyle.forSeverity(severity);
    final scale = isSelected ? 1.18 : 1.0;

    return Semantics(
      button: true,
      label: semanticLabel ?? '${style.label} severity incident',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: CustomPaint(
            painter: _PinPainter(
              color: style.color,
              borderColor: Colors.white,
              elevated: isSelected,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  style.icon,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.color,
    required this.borderColor,
    required this.elevated,
  });

  final Color color;
  final Color borderColor;
  final bool elevated;

  @override
  void paint(Canvas canvas, Size size) {
    final headRadius = size.width / 2;
    final headCentre = Offset(size.width / 2, headRadius);

    final path = Path()
      ..addOval(Rect.fromCircle(center: headCentre, radius: headRadius))
      ..moveTo(size.width * 0.5 - headRadius * 0.52, headRadius * 1.45)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.5 + headRadius * 0.52, headRadius * 1.45)
      ..close();

    if (elevated) {
      canvas.drawShadow(path, Colors.black54, 4.0, false);
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.elevated != elevated;
}

/// Pulsing blue dot marking the responder's own GPS position.
///
/// Anchored with `Alignment.center` — the dot centre is the coordinate.
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key, this.isStale = false});

  /// True when the fix is a fallback/last-known position rather than live GPS.
  final bool isStale;

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isStale
        ? AppColors.lightTextSecondary
        : AppColors.statusVerified;

    return Semantics(
      label: widget.isStale
          ? 'Approximate location'
          : 'Your current location',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding halo conveys "live GPS" without a second timer.
              Opacity(
                opacity: (1.0 - t) * 0.35,
                child: Container(
                  width: 18 + (26 * t),
                  height: 18 + (26 * t),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
