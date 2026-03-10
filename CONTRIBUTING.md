# Contributing to ReDock

Thank you for contributing to ReDock.

## Before You Start

- Search existing issues and pull requests before opening a new one.
- For behavior changes or larger features, open an issue first so the scope can be agreed before implementation.
- Keep pull requests focused. Avoid mixing unrelated refactors with feature work.

## Development Setup

```bash
swift build
swift test --parallel
bash scripts/bundle.sh
```

ReDock targets macOS 14 or later. Window-management features require Accessibility permission when running the app bundle locally.

## Pull Request Expectations

- Describe the problem, approach, and user-visible impact.
- Add or update tests when behavior changes.
- Update `README.md`, `README.ja.md`, or `CHANGELOG.md` when user-facing behavior changes.
- Keep code and documentation in English unless a file already uses another language.

## Coding Notes

- Prefer small, reviewable changes.
- Preserve existing architecture and naming unless there is a clear reason to change them.
- Do not commit build artifacts, generated app bundles, or local environment files.

## Reporting Bugs

Include:

- macOS version
- ReDock version or commit SHA
- Steps to reproduce
- Expected result
- Actual result
- Whether the issue reproduces with Accessibility permission re-enabled

## Security

Do not open public issues for vulnerabilities or sensitive security findings. Use the process in `SECURITY.md`.
