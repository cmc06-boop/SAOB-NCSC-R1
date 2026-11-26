import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the next numbered copy, including when the chosen name already
/// has a numeric suffix. Existing copies are never opened for writing.
Future<String> nextExportName(String folderPath, String fileName) async {
  final extension = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(stem);
  final base = match?.group(1) ?? stem;
  final requested = int.tryParse(match?.group(2) ?? '') ?? 0;
  var highest = -1;
  final names = <String>{};
  await for (final entry in Directory(folderPath).list(followLinks: false)) {
    final name = p.basename(entry.path).toLowerCase();
    names.add(name);
    if (p.extension(name) != extension.toLowerCase()) continue;
    final existing = p.basenameWithoutExtension(name);
    if (existing == base.toLowerCase()) {
      if (highest < 0) highest = 0;
      continue;
    }
    final suffix = RegExp(r'^(.*) \((\d+)\)$').firstMatch(existing);
    if (suffix?.group(1) != base.toLowerCase()) continue;
    final number = int.tryParse(suffix?.group(2) ?? '');
    if (number != null && number > highest) highest = number;
  }
  if (!names.contains(fileName.toLowerCase()) &&
      (highest < requested || highest < 0)) {
    return fileName;
  }
  final next = highest >= requested ? highest + 1 : requested + 1;
  return '$base ($next)$extension';
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
