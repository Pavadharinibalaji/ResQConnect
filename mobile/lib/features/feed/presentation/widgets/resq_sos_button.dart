import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ResQSosButton extends StatefulWidget {
  final VoidCallback? onSosTriggered;

  const ResQSosButton({
    super.key,
    this.onSosTriggered,
  });

  @override
  State<ResQSosButton> createState() => _ResQSosButtonState();
}

class _ResQSosButtonState extends State<ResQSosButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _countdownTimer;
  double _progress = 0.0;
  bool _isHolding = false;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _controller.addListener(() {
      setState(() {
        _progress = _controller.value;
      });
      if (_controller.isCompleted && !_isActivated) {
        _onHoldCompleted();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onHoldStarted() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = true;
      _progress = 0.0;
    });
    _controller.forward(from: 0.0);
  }

  void _onHoldCancelled() {
    if (!_isActivated) {
      HapticFeedback.lightImpact();
      _controller.reset();
      setState(() {
        _isHolding = false;
        _progress = 0.0;
      });
    }
  }

  void _onHoldCompleted() {
    HapticFeedback.vibrate();
    setState(() {
      _isActivated = true;
      _isHolding = false;
    });
    if (widget.onSosTriggered != null) {
      widget.onSosTriggered!();
    }
    _showSosConfirmationModal(context);
  }

  void _showSosConfirmationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          decoration: const BoxDecoration(
            color: AppColors.deepCharcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmergencyRed.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_rounded, color: AppColors.primaryEmergencyRed, size: 64),
              ),
              const SizedBox(height: AppTheme.spaceM),
              const Text(
                '🔴 EMERGENCY SOS ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Broadcasted your GPS coordinates & responder alert to 14 nearest emergency contacts & responders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: AppTheme.spaceL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isActivated = false;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('CANCEL SOS'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('TRACK RESPONSE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onHoldStarted(),
      onTapUp: (_) => _onHoldCancelled(),
      onTapCancel: _onHoldCancelled,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Progress Radial
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 6,
              backgroundColor: AppColors.primaryEmergencyRed.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryEmergencyRed),
            ),
          ),

          // Core SOS Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isHolding ? 68 : 64,
            height: _isHolding ? 68 : 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryEmergencyRed, AppColors.deepEmergencyRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmergencyRed.withValues(alpha: _isHolding ? 0.6 : 0.4),
                  blurRadius: _isHolding ? 20 : 12,
                  spreadRadius: _isHolding ? 4 : 1,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                  if (_isHolding)
                    Text(
                      '${(2.0 - (_progress * 2.0)).toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
