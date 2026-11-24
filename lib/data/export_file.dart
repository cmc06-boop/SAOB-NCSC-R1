import 'dart:io';

import 'package:path/path.dart' as p;

/// Saves a new export copy without replacing an existing PDF or Excel file.
///
/// Names are automatically suffixed: report.pdf, report (1).pdf, etc.
/// Exclusive creation also handles concurrent exports that choose the same name.
Future<String> saveExportCopy({
  required String folderPath,
  required String fileName,
  required List<int> bytes,
}) async {
  final baseName = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);
  for (var suffix = 0; ; suffix++) {
    final candidateName =
        suffix == 0 ? fileName : '$baseName ($suffix)$extension';
    final file = File(p.join(folderPath, candidateName));
    try {
      await file.create(exclusive: true);
    } on PathExistsException {
      // Never overwrite an older export; find the next available name.
      continue;
    }

    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      // Clean up only the newly-created, incomplete export.
      try {
        await file.delete();
      } on FileSystemException {
        // Preserve the original write error if cleanup also fails.
      }
      rethrow;
    }
  }
}
