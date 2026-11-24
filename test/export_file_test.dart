import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ncsc_region1_finance/data/export_file.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ncsc-export-test-');
  });

  tearDown(() async {
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  });

  test('first export uses its normal PDF filename', () async {
    final saved = await saveExportCopy(
      folderPath: folder.path,
      fileName: 'NCSC-R1-2026-All.pdf',
      bytes: [37, 80, 68, 70],
    );

    expect(p.basename(saved), 'NCSC-R1-2026-All.pdf');
    expect(await File(saved).readAsBytes(), [37, 80, 68, 70]);
  });

  test('existing PDF is untouched and extra exports gain numbers', () async {
    final original = File(p.join(folder.path, 'NCSC-R1-2026-All.pdf'));
    await original.writeAsBytes([1, 2, 3]);

    final second = await saveExportCopy(
      folderPath: folder.path,
      fileName: 'NCSC-R1-2026-All.pdf',
      bytes: [4, 5],
    );
    final third = await saveExportCopy(
      folderPath: folder.path,
      fileName: 'NCSC-R1-2026-All.pdf',
      bytes: [6, 7],
    );

    expect(p.basename(second), 'NCSC-R1-2026-All (1).pdf');
    expect(p.basename(third), 'NCSC-R1-2026-All (2).pdf');
    expect(await original.readAsBytes(), [1, 2, 3]);
    expect(await File(second).readAsBytes(), [4, 5]);
    expect(await File(third).readAsBytes(), [6, 7]);
  });

  test('existing Excel file is preserved with .xlsx suffix intact', () async {
    final original = File(p.join(folder.path, 'NCSC-R1-2026-GAS.xlsx'));
    await original.writeAsBytes([9, 9, 9]);

    final saved = await saveExportCopy(
      folderPath: folder.path,
      fileName: 'NCSC-R1-2026-GAS.xlsx',
      bytes: [8, 8],
    );

    expect(p.basename(saved), 'NCSC-R1-2026-GAS (1).xlsx');
    expect(await original.readAsBytes(), [9, 9, 9]);
    expect(await File(saved).readAsBytes(), [8, 8]);
  });

  test('concurrent exports never overwrite each other', () async {
    final saved = await Future.wait([
      for (var i = 0; i < 3; i++)
        saveExportCopy(
          folderPath: folder.path,
          fileName: 'report.pdf',
          bytes: [i],
        ),
    ]);

    expect(saved.map(p.basename).toSet(), {
      'report.pdf',
      'report (1).pdf',
      'report (2).pdf',
    });
    expect(
      (await Future.wait(saved.map((path) => File(path).readAsBytes())))
          .map((bytes) => bytes.single)
          .toSet(),
      {0, 1, 2},
    );
  });
}
