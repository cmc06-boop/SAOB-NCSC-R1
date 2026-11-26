import 'dart:io';

import 'package:path/path.dart' as p;

/// Automatic suggestions are not explicit renames. Recheck their base name
/// in the actual destination, even if files were deleted while Save As was open.
String resolveExportRequest({
  required String defaultName,
  required String suggestedName,
  required String chosenName,
}) => chosenName == suggestedName ? defaultName : chosenName;

/// Use the first available filename, starting with the unnumbered original.
/// Deleted copies release their names immediately; no historical counter.
Future<String> nextExportName(String folderPath, String fileName) async {
  final extension = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(stem);
  final base = match?.group(1) ?? stem;
  final names = <String>{};
  await for (final entry in Directory(folderPath).list(followLinks: false)) {
    names.add(p.basename(entry.path).toLowerCase());
  }
  // Honor an explicit, unused numbered name typed in Save As.
  if (match != null && !names.contains(fileName.toLowerCase())) {
    return fileName;
  }
  for (var suffix = 0; ; suffix++) {
    final candidate = suffix == 0 ? '$base$extension' : '$base ($suffix)$extension';
    if (!names.contains(candidate.toLowerCase())) {
      return candidate;
    }
  }
}

/// Create a new export file without replacing any existing file.
Future<String> saveExportCopy({
  required String folderPath,
  required String fileName,
  required List<int> bytes,
}) async {
  var candidateName = await nextExportName(folderPath, fileName);
  while (true) {
    final file = File(p.join(folderPath, candidateName));
    // Check explicitly as well as using exclusive creation.
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      candidateName = await nextExportName(folderPath, candidateName);
      continue;
    }
    try {
      await file.create(exclusive: true);
    } on PathExistsException {
      candidateName = await nextExportName(folderPath, candidateName);
      continue;
    }
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      try {
        await file.delete();
      } on FileSystemException {
        // Preserve original error.
      }
      rethrow;
    }
  }
}
