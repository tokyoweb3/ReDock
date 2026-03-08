# MWM — Mac Window Manager

A lightweight macOS window manager inspired by ShiftIt and Moom Classic. Snap windows to halves, quarters, and more with keyboard shortcuts. Save and restore multi-display layouts with context-aware auto-restore and workspace presets.

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
4. Five workspace presets (Coding, Research, Review, Meeting, Writing) are created automatically

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

**Default naming:** New layouts without a name default to "My Layout" (localized). Duplicate names are automatically suffixed with (1), (2), etc.

### Layout Editor

1. Open **Settings > Layouts**
2. Select a layout to see a visual minimap preview
3. Drag windows in the minimap to reposition, use snap presets for precise alignment
4. Edit layout name, mode, and window list
5. Save or Reset changes independently
6. Switching layouts with unsaved changes prompts a Save/Discard/Cancel dialog

**Editor features:**
- Re-snapshot current windows to update positions
- Add windows from running apps (single or multi-select)
- Reassign a window to a different app
- Snap presets: L1/2, R1/2, T1/2, B1/2, TL, TR, BL, BR, Max
- Remove individual windows with inline delete

### Display Variants & Profiles

Each layout supports **multiple display variants** — one per display profile (monitor configuration). This lets a single layout adapt to different setups (e.g., docked 3-screen at office vs. laptop-only at cafe).

- **Display profiles** are auto-detected when a new monitor configuration is seen
- Profiles are user-renamable in **Settings > Layouts > Display Profiles**
- The layout editor shows a profile picker to switch between variants
- The preview always shows all monitors from the selected profile
- Variants without windows show empty monitor shapes, ready for window placement

### Workspace Presets

Five built-in workspace presets optimized for common workflows:

| Preset | Layout | Shortcut |
|--------|--------|----------|
| Coding | Editor 60% + Terminal 20% + Browser 20% | Ctrl+Opt+5 |
| Research | Browser 50% + Notes 50% | Ctrl+Opt+6 |
| Review | Editor 50% + Terminal 50% | Ctrl+Opt+7 |
| Meeting | Browser maximized | Ctrl+Opt+8 |
| Writing | Editor centered 70% (+ Focus Mode) | Ctrl+Opt+9 |

Workspace slots 5–9 can be reassigned to any layout in **Settings > Shortcuts**.

### Auto-Restore

Automatically restore a layout variant when your display environment changes:

1. Open **Settings > Layouts** and select a layout
2. Select a display profile from the variant picker
3. Enable **Auto-restore** for that variant
4. When your displays match the profile, the variant restores automatically

**Per-variant control:**
- Auto-restore is configured per display variant, not per layout
- Each variant can independently enable/disable auto-restore and app launching
- Conflicts (multiple variants with the same display profile) are detected and shown as warnings

**Context Triggers:**
- **Display configuration** — Triggered by connecting/disconnecting monitors
- **Wi-Fi SSID** — Triggered by network changes (office vs. home setups)
- **Compound (AND)** — Combine multiple triggers for precise matching

### Focus Mode

Hides all apps except the frontmost one, helping you concentrate on a single task. The focused window is centered at 75% screen size. Toggle via the menu bar or shortcut (Ctrl+Opt+Z). Exiting restores all hidden apps and original window positions.

### Import / Export

Share or back up your layouts:

- **Export:** Menu bar > Export Layouts... (or Settings > Layouts toolbar)
- **Import:** Menu bar > Import Layouts... (or Settings > Layouts toolbar)

Layouts are exported as a versioned JSON bundle. On import:
- Each layout gets a new UUID to avoid conflicts
- Duplicate names are automatically disambiguated
- Auto-restore settings are cleared for safety
- Schema version compatibility is validated

### Diagnostics

Recent restore results are shown in the menu bar under **Recent Restores** (up to 10 entries), including which windows were restored, skipped, or failed — with specific reasons. Up to 50 records are persisted across sessions.

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

The language follows your system setting by default. You can override it in **Settings > General > Language**.

## Settings

Open via menu bar > **Settings...** (Cmd+,)

| Tab | Contents |
|-----|----------|
| Shortcuts | Customize all keyboard shortcuts, assign layouts to workspace slots 5–9 |
| Layouts | Manage layouts with visual editor, display variants, auto-restore, import/export, display profiles |
| General | Language selection, Launch at Login, version info |

## Architecture

```
Sources/MWM/
  App/              App lifecycle, menu bar (NSStatusItem+NSMenu), settings UI, localization
  Accessibility/    AXUIElement wrapper, permissions checking
  WindowManagement/ Window actions (strategy pattern), dispatcher, Stage Manager detection
  Screen/           Display detection, coordinate conversion, display profiles
  Layout/           Save/restore, variants, triggers, diagnostics, import/export,
                    auto-restore, app launch, workspace presets, window matching
  Hotkeys/          KeyboardShortcuts integration, layout/workspace slot shortcuts
  Focus/            Focus Mode service and session state
  Resources/        Localization strings (en, ja, zh-Hans, zh-Hant, ko, es, fr, de, pt-BR)
```

**Key patterns:**
- **Strategy pattern** — One calculation class per window action (HalfCalculation, QuarterCalculation, etc.)
- **AX wrapper** — `AccessibilityElement` with safe `UnsafeMutablePointer` pattern for AXValue extraction
- **Cross-display setFrame** — 3-step size→position→size to avoid OS clamping
- **Score-based matching** — `WindowMatcher` combines role, title, and frame proximity signals
- **Service container** — `AppServices` singleton with protocol-based dependencies for testability
- **Coordinate conversion** — CG (top-left origin) ↔ AppKit (bottom-left origin) via `ScreenGeometry`

**Storage:**
```
~/Library/Application Support/MWM/
  layouts/              Individual layout JSON files
  display-profiles.json Display profile configurations
  diagnostics.json      Restore history (last 50 records)
```

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

Some apps (e.g., Electron-based apps) may not respond to Accessibility setFrame commands. MWM verifies each window position after restore and reports failures individually in the Recent Restores menu.

## License

Private project.
