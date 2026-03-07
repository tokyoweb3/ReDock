# Changelog

## v2.0.0 — 2026-03-07

### New Features

- **Context-aware auto-restore** — Automatically restore layouts when display configuration or Wi-Fi network changes. Supports compound (AND) triggers.
- **App launch on restore** — Optionally launch missing apps before restoring a layout.
- **Stage Manager compatibility** — Detects Stage Manager and filters strip windows during save/restore.
- **Multi-language support** — 9 languages: English, Japanese, Simplified Chinese, Traditional Chinese, Korean, Spanish, French, German, Brazilian Portuguese. Switchable in Settings > General.
- **Layout editor** — Drag windows in a visual minimap, snap to presets, edit name/mode, save/reset independently.
- **Template mode** — Apply saved positions to the N most recently used windows, regardless of app.
- **Import/Export** — Share layouts as versioned JSON files. Duplicate names auto-disambiguated on import.
- **Diagnostics** — Recent restore results with per-window success/skip/fail details shown in menu bar.
- **Restore verification** — Post-restore position verification detects uncooperative apps.

### Improvements

- Window matcher uses single-removal to prevent double-matching identical windows
- Auto-restore guard prevents concurrent restore operations
- Import deduplicates layout names automatically
- Layout save dialog allows selecting specific windows and choosing mode

### Architecture

- `ContextResolver` / `ContextTrigger` for environment-aware automation
- `RestorePlanner` / `AppLaunchService` for pre-restore app launching
- `DiagnosticsService` for persistent restore records
- `ImportExportService` with schema versioning and validation
- `StageManagerDetector` for macOS Stage Manager detection
- `LocalizationManager` with per-language bundle resolution

## v1.0.0

### Features

- Window snapping: halves, quarters, maximize, center, full screen
- Incremental resize (larger/smaller)
- Multi-display: move windows between screens
- Focus Mode: hide all except frontmost app
- Layout save & restore with relative frame positioning
- Menu bar UI with keyboard shortcut display
- Settings: customizable shortcuts, layout management, launch at login
- Auto-restore on display configuration change
