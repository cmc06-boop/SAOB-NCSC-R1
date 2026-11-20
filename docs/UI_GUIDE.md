# Pag-edit ng Flutter UI

Buksan ang project folder sa VS Code at install ang Flutter extension. Patakbuhin ang `flutter run -d windows`.

## Paliitin ang login container

Sa `lib/ui/theme.dart`, hanapin ang `LoginLayout`:

```dart
static const cardWidth = 360.0;
static const cardPadding = 28.0;
static const cardRadius = 28.0;
static const fieldHeight = 48.0;
```

Halimbawa, palitan ang `360.0` ng `340.0` para kumitid nang 20 logical pixels. I-save at pindutin ang Hot Reload button, o `r` sa terminal na may running Flutter app. Logical pixels ang sizes; maaaring mas marami ang physical pixels kapag naka-125% o 150% Windows scaling.

## Main colors

Sa parehong `theme.dart`:

- `navy`: sidebar, login button, main branding.
- `blue`: primary buttons, selected menu, chart.
- `red`: small accents at important action/error text.
- `background`, `line`, `ink`, `muted`: background, borders, at text.

## Aling file ang ie-edit

| File | Laman |
| --- | --- |
| `lib/features/login_page.dart` | Login form, branding, local first-account setup |
| `lib/ui/login_backdrop.dart` | Original senior photo and background composition |
| `lib/ui/app_shell.dart` | Sidebar and signed-in header |
| `lib/features/dashboard_page.dart` | Metrics, item filter, donut, rates |
| `lib/features/budget_page.dart` | Budget list and record editor |
| `lib/features/import_page.dart` | Excel worksheet preview and import |
| `lib/features/reports_page.dart` | Report filters, preview, exports, history |
| `lib/features/audit_page.dart` | Audit table and filters |
| `lib/features/settings_page.dart` | Programs and UACS reference forms |
| `lib/ui/common.dart` | Reusable panels, tables, dropdowns, and pagination |
| `lib/data/finance_store.dart` | Database operations and finance rules |

Ang form at layout text ay totoong Flutter widgets, kaya editable sila sa code. Yung photo/background ay assets. Walang sun o footer caption na idinagdag.

Hot Reload para sa maraming Dart/UI edits. Kapag dependencies, `main()`, o native Windows files ang binago, maaaring kailangan ng Hot Restart o stop/run ulit.

## Native title bar

Ang title text ay nasa `windows/runner/main.cpp`. Ang native title-bar icon handling at minimum window size ay nasa `windows/runner/flutter_window.cpp`. Ang light gray caption color ay nasa `windows/runner/win32_window.cpp`. Kailangan ng full Windows rebuild para sa mga ito.
