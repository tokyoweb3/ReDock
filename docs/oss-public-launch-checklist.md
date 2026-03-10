# OSS Public Launch Checklist

This checklist is for the first public release of ReDock.

## GitHub Repository Metadata

- **Description:** Lightweight macOS window manager with snapping, saved layouts, auto-restore, and workspace presets.
- **Homepage:** Set this after the first public release page or project website exists.
- **Suggested topics:** `macos`, `swift`, `swift-package-manager`, `window-manager`, `productivity`, `menu-bar`, `accessibility`, `tiling-window-manager`, `layout-manager`

## Before Making the Repository Public

- Confirm `LICENSE`, `README.md`, `README.ja.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md` are present.
- Confirm no tracked files contain secrets, private tokens, or personal data.
- Confirm release artifacts are described honestly as preview-quality while the app is still ad-hoc signed.
- Decide the private security contact path that will be used in `SECURITY.md`.

## First Public Release Notes

- State that local build is the primary supported install path for now.
- State that GitHub release DMGs are preview-quality until Developer ID signing and notarization are complete.
- Link to known limitations in `README.md`.

## After Public Launch

- Watch incoming bug reports for setup friction around Accessibility permission and Gatekeeper warnings.
- Decide whether to disable blank GitHub issues or leave them enabled for early feedback.
- Prioritize Developer ID signing and notarization once users start downloading release artifacts directly.
