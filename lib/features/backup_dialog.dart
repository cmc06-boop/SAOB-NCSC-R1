import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key, required this.store});
  final FinanceStore store;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _source, _error, _message;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() { _busy = true; _error = null; _message = null; });
    try {
      final folder = await getDirectoryPath(confirmButtonText: 'Save here');
      if (!mounted || folder == null) return;
      final result = widget.store.createBackup(folder);
      setState(() => _message = 'Backup saved to $result');
    } catch (_) {
      if (mounted) setState(() => _error = 'Backup failed. Check the destination and available disk space.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseRestore() async {
    setState(() { _busy = true; _error = null; _message = null; });
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'NCSC database backup', extensions: ['db']),
      ]);
      if (!mounted || file == null) return;
      setState(() { _source = file.path; _password.clear(); });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to select the backup file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_source == null || _password.text.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      final safety = await widget.store.restoreBackup(_source!, _password.text);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(safety);
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _busy = false; });
    }
  }

  Widget _section(String icon, String title, String detail, Widget action) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffdce4f3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon == 'backup'
                    ? const Icon(Icons.backup_outlined, color: blue, size: 25)
                    : AppIcon(icon, color: blue, size: 25),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(detail, style: const TextStyle(color: muted, fontSize: 13)),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final last = DateTime.tryParse(widget.store.lastBackup ?? '');
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const SizedBox(width: 40),
            const Expanded(
              child: Text('Backup & Restore', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 20)),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                tooltip: 'Close',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: muted),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Protect and recover your financial records.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xffedf3fe), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Last Backup', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                    const SizedBox(height: 4),
                    Text(last == null ? 'No backup created yet.' : last.toIso8601String().replaceFirst('T', ' ').split('.').first, style: const TextStyle(color: muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                _section('backup', 'Create Backup',
                  'Save a complete database copy to an office-approved secure drive or folder.',
                  HoverScaleButton(
                    enabled: !_busy,
                    child: FilledButton(onPressed: _busy ? null : _create, child: const Text('Create Backup')),
                  )),
                const SizedBox(height: 12),
                _section('history', 'Restore Backup',
                  'Recover records from an existing backup file.',
                  HoverScaleButton(
                    enabled: !_busy,
                    child: OutlinedButton(onPressed: _busy ? null : _chooseRestore, child: const Text('Select Backup File')),
                  )),
                if (_source != null) ...[
                  const SizedBox(height: 14),
                  Text(p.basename(_source!), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Restoring replaces current database records. A safety backup is saved locally first. You will sign in again using the administrator credentials from the backup.', style: TextStyle(color: red, fontSize: 13)),
                  const SizedBox(height: 10),
                  TextField(controller: _password, enabled: !_busy, obscureText: true,
                    autocorrect: false, enableSuggestions: false,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Current administrator password')),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _busy || _password.text.isEmpty ? null : _restore,
                    style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white),
                    child: const Text('Confirm Restore')),
                ],
                if (_busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
                if (_message != null) ...[const SizedBox(height: 10), Text(_message!, style: const TextStyle(color: navy))],
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: red))],
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            height: 40,
            child: HoverScaleButton(
              enabled: !_busy,
              child: TextButton(
                style: dialogCancelStyle(),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
