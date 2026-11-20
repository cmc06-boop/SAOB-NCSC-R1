# Validation record

Development environment: Flutter 3.50.0 stable, Dart 3.14.0, Linux headless Flutter test runner.

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --reporter expanded`: **21 tests passed** (15 finance/data tests and 6 UI tests).
- `flutter pub get --offline`: dependency lock resolves successfully from the validated environment.

| Check | Result |
| --- | --- |
| Peso input and sums use integer cents in app calculations | Passed |
| Python PBKDF2 password compatibility | Passed against a Python-generated hash |
| Add/edit, duplicate guard, amount validation, audit updates | Passed |
| Atomic Excel imports, duplicate prevention, explicit existing-record updates | Passed |
| Inactive programs retain history; new records require an active program | Passed |
| Service permissions for existing migrated roles | Passed |
| Automatic fiscal year creation without copying budget amounts | Passed |
| Manila audit date boundaries | Passed |
| Python SQLite account and record migration | Passed with synthetic Python-generated fixture |
| Committed WAL records included during migration | Passed |
| Invalid legacy database leaves no partial destination | Passed |
| Account and record persistence after close/reopen | Passed |
| Excel cached formulas, uncached formula errors, and data beyond row 200 | Passed |
| Excel numeric export/import round-trip and distinct report columns | Passed |
| Offline PDF generation with bundled logo and fonts | Passed |
| Login layout and password toggle at 1000×620, 1366×720, 1920×1080 | Passed |
| Populated menus and record editor at 1000×650, 1366×720, 1920×1080 | Passed |

Login and dashboard were also reviewed with headless Flutter rendering. This does not validate native Windows decorations.

The original four PNG assets are byte-identical to the Python source assets. In particular, `login-senior.png` SHA-256 remains:

```text
027f351573c1980e7cdf8e33628d765c2af9626982e24c58ab85267986a03011
```

## Windows checks still required

A Windows executable has not been built or run in this Linux environment. On the development Windows laptop:

1. Run `flutter doctor -v` and complete the Windows toolchain setup.
2. Run `flutter run -d windows`; check the native gray title bar, title text, absence of a caption logo, resizing, and 100%/125%/150% scaling.
3. Select a real SAOB workbook. Confirm program, fund, year, preview amounts, invalid-row messages, and the saved records against the source workbook.
4. Try the Windows save dialogs for Excel/PDF and the actual office printer.
5. Close/reopen the app and verify retained records. If migrating existing data, compare totals with the Python app before adopting the Flutter version.
6. Build the Windows release and test the complete Release folder offline on the intended AO machine.

No production financial database is included. The fixture database and workbook contain synthetic data only.
