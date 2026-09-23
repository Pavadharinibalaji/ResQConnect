import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/features/feed/domain/repositories/incident_repository.dart';

/// Outcome of uploading the evidence files attached to a new incident.
class EvidenceUploadResult {
  final int attempted;

  /// One user-facing reason per failed file.
  final List<String> failureMessages;

  const EvidenceUploadResult({required this.attempted, required this.failureMessages});

  int get failed => failureMessages.length;
  int get succeeded => attempted - failed;
  bool get allSucceeded => failureMessages.isEmpty;

  /// Summary for the report dialog; null when every file was uploaded.
  String? get failureSummary {
    if (allSucceeded) return null;
    final reasons = failureMessages.toSet().join('\n');
    final noun = attempted == 1 ? 'file' : 'files';
    return '$failed of $attempted evidence $noun could not be uploaded:\n$reasons';
  }
}

/// Uploads each file in turn; one failure does not stop the others, and none is swallowed.
Future<EvidenceUploadResult> uploadEvidenceFiles(
  IncidentRepository repository,
  String incidentId,
  Iterable<({String path, String type})> files,
) async {
  var attempted = 0;
  final failures = <String>[];
  for (final file in files) {
    attempted++;
    try {
      await repository.uploadEvidence(incidentId, file.path, file.type);
    } catch (e) {
      failures.add(ApiErrorParser.fromError(e, fallbackMessage: 'The evidence file could not be uploaded.').message);
    }
  }
  return EvidenceUploadResult(attempted: attempted, failureMessages: failures);
}
