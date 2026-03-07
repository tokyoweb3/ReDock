# MWM — Mac Window Manager

A lightweight macOS window manager inspired by ShiftIt and Moom Classic. Snap windows to halves, quarters, and more with keyboard shortcuts. Save and restore multi-display layouts with context-aware auto-restore.

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
# Build, create .app bundle, and codesign
bash scripts/bundle.sh

# Launch
open build/MWM.app

# Stop
pkill -f MWM.app
```

## First Launch Setup

1. Run `open build/MWM.app`
2. macOS will prompt for **Accessibility permission** — grant it in System Settings > Privacy & Security > Accessibility
3. MWM appears as a menu bar icon (grid icon)

> **After rebuilding:** The binary hash changes, so macOS invalidates the permission. Toggle MWM **off then on** in Accessibility settings.

## Features

### Window Snapping

Use keyboard shortcuts to snap the focused window:

| Action | Default Shortcut |
|--------|-----------------|
| Left Half | Ctrl+Opt+Left |
| Right Half | Ctrl+Opt+Right |
| Top Half | Ctrl+Opt+Up |
| Bottom Half | Ctrl+Opt+Down |
| Top Left | Ctrl+Opt+U |
| Top Right | Ctrl+Opt+I |
| Bottom Left | Ctrl+Opt+J |
| Bottom Right | Ctrl+Opt+K |
| Maximize | Ctrl+Opt+Return |
| Center | Ctrl+Opt+C |
| Full Screen | Ctrl+Opt+F |
| Make Larger | Ctrl+Opt+= |
| Make Smaller | Ctrl+Opt+- |
| Next Display | Ctrl+Opt+Cmd+Right |
| Prev Display | Ctrl+Opt+Cmd+Left |
| Focus Mode | Ctrl+Opt+Z |

All shortcuts are customizable in **Settings > Shortcuts**.

### Layout Save & Restore

Save the current arrangement of all windows and restore it later.

**Save:**
1. Arrange your windows as desired
2. Click the MWM menu bar icon > **Save Layout...**
3. Select windows to include, choose a mode (App-Specific or Template), and click Save

**Restore:**
1. Click MWM menu bar icon > **Restore Layout** > select a layout
2. Or use **Restore (Launch Apps)** to also open any apps that aren't running

**Layout Modes:**
- **App-Specific** — Matches windows by app bundle ID. Restores each app to its saved position.
- **Template** — Applies saved positions to the N most recently used windows, regardless of app.

**Layout Editor:**
1. Open **Settings > Layouts**
2. Select a layout to see a visual minimap preview
3. Drag windows in the minimap to reposition, use snap presets for precise alignment
4. Edit layout name, mode, and window list
5. Save or Reset changes independently

### Auto-Restore

Automatically restore a layout when your environment changes:

1. Open **Settings > Layouts**
2. Select a layout and enable **Auto-restore**
3. The current display configuration is saved as the trigger
4. When you connect/disconnect displays matching the trigger, the layout restores automatically

**Context Triggers:**
- **Display configuration** — Triggered by connecting/disconnecting monitors
- **Wi-Fi SSID** — Triggered by network changes (office vs. home setups)
- **Compound (AND)** — Combine multiple triggers for precise matching

Conflicts between layouts with overlapping triggers are detected and shown in the UI.

### Focus Mode

Hides all apps except the frontmost one, helping you concentrate on a single task. Toggle via the menu bar or shortcut.

### Import / Export

Share or back up your layouts:

- **Export:** Menu bar > Export Layouts... (or Settings > Layouts toolbar)
- **Import:** Menu bar > Import Layouts... (or Settings > Layouts toolbar)

Layouts are exported as a versioned JSON file. On import, duplicate names are automatically disambiguated and auto-restore triggers are cleared for safety.

### Diagnostics

Recent restore results are shown in the menu bar under **Recent Restores**, including which windows were restored, skipped, or failed — with specific failure reasons.

### Stage Manager Compatibility

MWM detects Stage Manager and automatically filters out its strip windows during layout save and restore, preventing interference with window management operations.

### Multi-Language Support

MWM supports 9 languages:

| Language | |
|----------|---|
| English | Default |
| 日本語 (Japanese) | |
| 简体中文 (Simplified Chinese) | |
| 繁體中文 (Traditional Chinese) | |
| 한국어 (Korean) | |
| Español (Spanish) | |
| Français (French) | |
| Deutsch (German) | |
| Português (Brazilian Portuguese) | |

The language follows your system setting by default. You can override it in **Settings > General > Language**. The system-detected language is annotated with "(System)" in the picker.

## Settings

Open via menu bar > **Settings...** (Cmd+,)

| Tab | Contents |
|-----|----------|
| Shortcuts | Customize all keyboard shortcuts |
| Layouts | Manage saved layouts with visual preview, drag editor, auto-restore, import/export |
| General | Language selection, Launch at Login, version info |

## Troubleshooting

### "0 windows" when saving a layout

Accessibility permission is not active. Fix:

1. Open System Settings > Privacy & Security > Accessibility
2. Find MWM in the list
3. Toggle it **off**, then **on** again
4. Try saving again

This is needed after every rebuild because the binary signature changes.

### Window snapping doesn't work

Same cause as above — Accessibility permission needs to be re-granted after rebuild.

### Shortcuts don't appear in the menu

Shortcuts are set to defaults on first launch. If they appear blank, open Settings > Shortcuts and click each recorder to assign shortcuts.

### Restore says "failed" for some windows

Some apps (e.g., Electron-based apps) may not respond to Accessibility setFrame commands. MWM verifies each window position after restore and reports failures individually.

## Architecture

```
Sources/MWM/
  App/              App lifecycle, menu bar, settings UI, localization
  Accessibility/    AXUIElement wrapper, permissions
  WindowManagement/ Window actions, calculations, dispatcher, Stage Manager
  Screen/           Display detection, coordinate conversion
  Layout/           Save/restore, triggers, diagnostics, import/export, auto-restore
  Hotkeys/          KeyboardShortcuts integration
  Focus/            Focus Mode service
  Resources/        Localization strings (en, ja, zh-Hans, zh-Hant, ko, es, fr, de, pt-BR)
```

## License

Private project.
