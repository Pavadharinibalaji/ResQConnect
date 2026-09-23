import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/features/feed/data/evidence_media_loader.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';

/// Shows protected photo evidence, fetched with the user's credentials.
///
/// `Image.network` cannot be used: evidence is only served to authorised users and
/// it would send no `Authorization` header. Failures (401, 403, 404, network, bad
/// URL, undecodable image) render [EvidenceUnavailable] instead.
class AuthenticatedEvidenceImage extends ConsumerStatefulWidget {
  final String fileUrl;
  final BoxFit fit;

  /// Thumbnail mode: icon plus a short label.
  final bool compact;
  final Color? foregroundColor;

  const AuthenticatedEvidenceImage({
    super.key,
    required this.fileUrl,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.foregroundColor,
  });

  @override
  ConsumerState<AuthenticatedEvidenceImage> createState() => _AuthenticatedEvidenceImageState();
}

class _AuthenticatedEvidenceImageState extends ConsumerState<AuthenticatedEvidenceImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedEvidenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileUrl != widget.fileUrl) {
      _bytes = _load();
    }
  }

  Future<Uint8List> _load() => ref.read(evidenceMediaLoaderProvider).loadBytes(widget.fileUrl);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) {
          final error = snapshot.error;
          final failure = error is EvidenceLoadFailure
              ? error
              : const EvidenceLoadFailure(EvidenceLoadError.unavailable);
          return EvidenceUnavailable(
            failure: failure,
            compact: widget.compact,
            foregroundColor: widget.foregroundColor,
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => EvidenceUnavailable(
            failure: const EvidenceLoadFailure(EvidenceLoadError.unavailable),
            compact: widget.compact,
            foregroundColor: widget.foregroundColor,
          ),
        );
      },
    );
  }
}

/// Neutral placeholder shown when evidence cannot be displayed.
class EvidenceUnavailable extends StatelessWidget {
  final EvidenceLoadFailure failure;
  final bool compact;
  final Color? foregroundColor;

  const EvidenceUnavailable({
    super.key,
    required this.failure,
    this.compact = false,
    this.foregroundColor,
  });

  IconData get _icon {
    switch (failure.reason) {
      case EvidenceLoadError.unauthorized:
      case EvidenceLoadError.forbidden:
        return Icons.lock_rounded;
      case EvidenceLoadError.notFound:
        return Icons.image_not_supported_rounded;
      case EvidenceLoadError.network:
        return Icons.wifi_off_rounded;
      case EvidenceLoadError.invalidUrl:
      case EvidenceLoadError.unavailable:
        return Icons.broken_image_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: failure.message,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: color, size: compact ? 28 : 56),
              SizedBox(height: compact ? 4 : 12),
              Text(
                compact ? failure.shortMessage : failure.message,
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: compact ? 10 : 13, fontWeight: compact ? FontWeight.bold : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
