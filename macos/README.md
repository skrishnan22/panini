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

## Release Validation

After a Release build or export, validate the exported app:

```bash
APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Release/Panini.app' -print -quit)"
test -n "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvvv --entitlements :- "$APP_PATH"
spctl -a -vvv -t exec "$APP_PATH"
```

Expected:

- `codesign --verify` exits 0.
- Entitlements do not include `com.apple.security.get-task-allow`.
- Local development builds are usually signed ad hoc with hardened runtime.
- `spctl` reports the app is accepted only after Developer ID signing and notarization.

## Runtime Storage

Panini writes user-owned runtime data under `~/Library/Application Support/Panini`:

- `dictionary.json` stores the local custom dictionary.
- `Models/` stores Hugging Face snapshots downloaded by `mlx-swift-lm`.

The app intentionally does not bundle model weights. Users download and delete local models from Settings > Models.

## Manual verification checklist

1. Build and run the `Panini` scheme from Xcode.
2. Grant Accessibility permission and relaunch the app if prompted.
3. Open Settings > Models and download `Qwen 2.5 3B` if it is not already present.
4. In Settings > General, confirm the provider is `Local` and the active model is `Qwen 2.5 3B`.
5. In Notes, run review mode and verify capitalization and punctuation fixes are applied.
6. In Mail or Slack, run review mode and verify direct replacement works, or clipboard fallback replaces the exact selection.
7. Run autofix and verify Undo restores the prior text inside the undo window.

## Xcode Run Configuration

No Python server environment variables are required.

## Known limitations

- Cloud provider setup is intentionally not wired yet.
- Active MLX downloads cannot be canceled once started.
- Google Docs and canvas-style editors are not reliably writable.
- Accessibility writes can fail per target app policy; clipboard/manual copy remain available.
