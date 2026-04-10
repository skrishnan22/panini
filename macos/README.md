# Panini macOS Thin Client

Menu bar macOS client for Panini local inference.

## What this includes

- Menu bar shell with review/autofix commands
- Global hotkey registration
- Local server lifecycle and health probing
- Accessibility text read/write with clipboard fallback
- Review mode and auto-fix mode with undo buffer
- Dictionary integration against localhost server endpoints

## Build (XcodeGen flow)

```bash
cd panini/macos
xcodegen generate
xcodebuild -project Panini.xcodeproj -scheme Panini -sdk macosx build
```

## Test

```bash
cd panini/macos
xcodebuild test -project Panini.xcodeproj -scheme Panini -destination 'platform=macOS'
```

## Local verification checklist

1. Grant Accessibility permission and relaunch the app.
2. In Notes, run review mode and verify Apply replaces the exact selected text.
3. In Mail composer, run review mode and verify Apply replaces the exact selected text without requiring a second click in the editor.
4. In Slack desktop, run review mode and verify either direct replacement works or clipboard fallback replaces the exact selection.
5. In all three apps, verify Copy still works even if Apply fails.

## Xcode Run Configuration (recommended)

When running from Xcode, set these Scheme Environment Variables so auto-start can find the backend:

- `PANINI_SERVER_DIR=/Users/skrishnan/development/panini/server`
- `PANINI_PYTHON_PATH=/Users/skrishnan/development/panini/server/.venv/bin/python3`

Optional:

- `PANINI_SERVER_HOST=127.0.0.1`
- `PANINI_SERVER_PORT=8765`
- `PANINI_MODEL_ID=qwen-2.5-3b`

Note: The current MLX runtime in this project may not support Gemma 4 model types. Use `qwen-2.5-3b` as the default local model unless Gemma 4 support is confirmed in your installed `mlx-lm` version.

## Known limitations

- Google Docs and canvas-style editors are not reliably writable.
- Accessibility writes can fail per target app policy; clipboard/manual copy remain available.
