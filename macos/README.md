# Panini macOS App

Menu bar macOS client for native local inference.

## What this includes

- Menu bar review and autofix actions
- Native MLX Swift local inference
- Local model download and selection
- Accessibility text read/write with clipboard fallback
- Review mode and autofix mode with undo buffer
- Local dictionary management

## Build

```bash
cd panini/macos
xcodebuild -project Panini.xcodeproj -scheme Panini -destination 'platform=macOS' build
```

## Test

```bash
cd panini/macos
xcodebuild test -project Panini.xcodeproj -scheme Panini -destination 'platform=macOS'
```

## Manual verification checklist

1. Build and run the `Panini` scheme from Xcode.
2. Grant Accessibility permission and relaunch the app if prompted.
3. Open Settings > Models and download `Qwen 2.5 3B` if it is not already present.
4. In Settings > General, confirm the provider is `Local` and the active model is `qwen-2.5-3b`.
5. In Notes, run review mode and verify capitalization and punctuation fixes are applied.
6. In Mail or Slack, run review mode and verify direct replacement works, or clipboard fallback replaces the exact selection.
7. Run autofix and verify Undo restores the prior text inside the undo window.

## Xcode Run Configuration

No Python server environment variables are required.

## Known limitations

- Cloud provider setup is intentionally not wired yet.
- Google Docs and canvas-style editors are not reliably writable.
- Accessibility writes can fail per target app policy; clipboard/manual copy remain available.
