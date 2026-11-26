import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Preserves editable Excel formulas while also writing initial calculated
/// values into XLSX cells for viewers that do not recalculate on load.
/// Cache values are only a display fallback; the `<f>` formulas remain intact.
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
    if (file.isFile && sheet != null) {
      var xml = utf8.decode(file.content as List<int>);
      for (final cell in (cells ?? const <String, String>{}).entries) {
        xml = xml.replaceFirstMapped(
          RegExp('<c r="${cell.key}"([^>]*)><f>([^<]*)</f><v></v>'),
          (m) =>
              '<c r="${cell.key}"${m[1]}><f>${m[2]}</f><v>${cell.value}</v>',
        );
      }
      xml = _configureWorksheet(xml, summary: sheet == 'SUMMARY');
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


/// Native XLSX settings; preserve all cell formulas, styles, and sheet order.
/// Summary titles occupy three rows; its section headings may appear later.
String _configureWorksheet(String source, {required bool summary}) {
  final document = XmlDocument.parse(source);
  final root = document.rootElement;
  XmlElement? child(XmlElement node, String name) =>
      node.childElements.where((e) => e.name.local == name).firstOrNull;
  XmlElement element(String name, Map<String, String> attrs) =>
      XmlElement(XmlName(name, root.name.prefix), [
        for (final pair in attrs.entries)
          XmlAttribute(XmlName(pair.key), pair.value),
      ]);
  void insertBefore(XmlElement value, Set<String> successors) {
    final index = root.children.indexWhere((node) =>
        node is XmlElement && successors.contains(node.name.local));
    if (index < 0) {
      root.children.add(value);
    } else {
      root.children.insert(index, value);
    }
  }

  var properties = child(root, 'sheetPr');
  if (properties == null) {
    properties = element('sheetPr', {});
    root.children.insert(0, properties);
  }
  final pageProperties = child(properties, 'pageSetUpPr');
  if (pageProperties == null) {
    properties.children.add(element('pageSetUpPr', {'fitToPage': '1'}));
  } else {
    pageProperties.setAttribute('fitToPage', '1');
  }

  var views = child(root, 'sheetViews');
  if (views == null) {
    views = element('sheetViews', {});
    insertBefore(views, {
      'sheetFormatPr', 'cols', 'sheetData', 'sheetProtection',
      'mergeCells', 'pageMargins', 'pageSetup',
    });
  }
  var view = child(views, 'sheetView');
  if (view == null) {
    view = element('sheetView', {'workbookViewId': '0'});
    views.children.add(view);
  }
  view.children.removeWhere((node) =>
      node is XmlElement && {'pane', 'selection'}.contains(node.name.local));
  final topRow = summary ? '6' : '4';
  view.children.insert(0, element('pane', {
    'ySplit': summary ? '5' : '3',
    'topLeftCell': 'A$topRow',
    'activePane': 'bottomLeft',
    'state': 'frozen',
  }));
  view.children.insert(1, element('selection', {
    'pane': 'bottomLeft', 'activeCell': 'A$topRow', 'sqref': 'A$topRow',
  }));

  root.children.removeWhere((node) =>
      node is XmlElement && {'pageMargins', 'pageSetup'}.contains(node.name.local));
  const afterMargins = {
    'printOptions', 'headerFooter', 'rowBreaks', 'colBreaks', 'customProperties',
    'cellWatches', 'ignoredErrors', 'smartTags', 'drawing', 'legacyDrawing',
    'legacyDrawingHF', 'picture', 'oleObjects', 'controls', 'webPublishItems',
    'tableParts', 'extLst',
  };
  // printOptions precedes pageMargins in the worksheet schema.
  final successors = {...afterMargins}..remove('printOptions');
  insertBefore(element('pageMargins', {
    'left': '0.3', 'right': '0.3', 'top': '0.4', 'bottom': '0.4',
    'header': '0.15', 'footer': '0.15',
  }), successors);
  insertBefore(element('pageSetup', {
    'paperSize': '9', 'orientation': 'landscape',
    'fitToWidth': '1', 'fitToHeight': '0',
  }), successors);
  return document.toXmlString();
}
