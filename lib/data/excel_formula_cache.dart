import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Preserves editable Excel formulas while also writing initial calculated
/// values into XLSX cells for viewers that do not recalculate on load.
/// Cache values are only a display fallback; the <f> formulas remain intact.
Uint8List excelWithCachedFormulas(
  Uint8List bytes,
  Map<String, Map<String, String>> cache,
) {
  if (cache.isEmpty) return bytes;
  final zip = ZipDecoder().decodeBytes(bytes);
  final workbook = zip.files.where((f) => f.name == 'xl/workbook.xml');
  final rels = zip.files.where((f) => f.name == 'xl/_rels/workbook.xml.rels');
  if (workbook.isEmpty || rels.isEmpty) return bytes;
  final idToTarget = <String, String>{};
  for (final match in RegExp(
    'Id="(rId\\d+)"[^>]*Target="([^"]+)"',
  ).allMatches(utf8.decode(rels.first.content as List<int>))) {
    var target = match.group(2)!;
    if (!target.startsWith('xl/')) target = 'xl/$target';
    idToTarget[match.group(1)!] = target.replaceAll('\\', '/');
  }
  final sheetFile = <String, String>{};
  for (final match in RegExp(
    'name="([^"]+)"[^>]*r:id="(rId\\d+)"',
  ).allMatches(utf8.decode(workbook.first.content as List<int>))) {
    final target = idToTarget[match.group(2)!];
    if (target != null) sheetFile[match.group(1)!] = target;
  }
  final out = Archive();
  for (final file in zip.files) {
    final sheet = sheetFile.entries
        .where((e) => e.value == file.name)
        .map((e) => e.key)
        .firstOrNull;
    final cells = sheet == null ? null : cache[sheet];
    if (file.isFile && cells != null && cells.isNotEmpty) {
      var xml = utf8.decode(file.content as List<int>);
      for (final cell in cells.entries) {
        xml = xml.replaceFirstMapped(
          RegExp('<c r="${cell.key}"([^>]*)><f>([^<]*)</f><v></v>'),
          (m) =>
              '<c r="${cell.key}"${m[1]}><f>${m[2]}</f><v>${cell.value}</v>',
        );
      }
      final data = utf8.encode(xml);
      out.addFile(ArchiveFile(file.name, data.length, data));
    } else {
      out.addFile(file);
    }
  }
  final packed = ZipEncoder().encode(out);
  if (packed == null || packed.isEmpty) return bytes;
  return Uint8List.fromList(packed);
}

