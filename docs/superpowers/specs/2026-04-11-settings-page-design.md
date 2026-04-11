# Settings Page Design

**Date:** 2026-04-11
**Status:** Approved

## Overview

Replace the current read-only `SettingsView` with a fully configurable settings window. Uses SwiftUI's `Settings` scene (Cmd+,) with a native macOS tabbed layout, styled with Panini's visual accents — serif section headers, green accent color, warm palette.

The goal is to surface existing configuration knobs (model, backend, preset, hotkeys) that are currently hidden behind environment variables and CLI args, and add model download management so the app doesn't download on first correction.

## Architecture

### Persistence

- **UserDefaults** (via `@AppStorage`): default preset, launch at login, backend choice (local/cloud), hotkey selections, selected model ID
- **macOS Keychain**: Vercel AI Gateway API key (Security framework wrapper, no third-party deps)
- **Server-side** (unchanged): user dictionary at `~/Library/Application Support/Panini/dictionary.json`

### Settings flow

`SettingsViewModel` becomes the source of truth for app configuration. Other components observe it:

- `CorrectionCoordinator` reads: default preset, selected model ID, backend choice
- `GlobalHotkeyManager` reads: hotkey bindings — re-registers when they change
- `ServerProcessManager` reads: backend choice, model ID — restarts server with new CLI args when these change
- `CorrectionAPIClient` reads: backend choice — adjusts request parameters

When backend or model changes, the server restarts with updated CLI args. Runtime config update endpoint deferred to later.

### New server endpoints

For model download management:

- `GET /models/{id}/status` — returns download state: `not_downloaded`, `downloading` (with progress), `ready`
- `POST /models/{id}/download` — initiates model download, returns immediately
- `DELETE /models/{id}` — deletes downloaded model files
- `GET /models/{id}/download/progress` — polling endpoint for download progress (percentage, bytes downloaded/total). Client polls on a timer while download is active.

## Tab Structure

### 1. General

The landing page. Four grouped sections:

**Backend** (top, prominent)
- Segmented control: "Local (MLX)" / "Cloud (Vercel AI Gateway)"
- Helper text changes based on selection:
  - Local: "Running on-device with downloaded models. No data leaves your machine."
  - Cloud: "Using Vercel AI Gateway. Text is sent to cloud for processing."
- Selecting Cloud grays out model-related UI elsewhere and makes the Cloud tab active/relevant

**Default Preset**
- Five pill-shaped chips: Fix, Improve, Professional, Casual, Paraphrase
- Single selection — the active one gets green fill with dark green text
- Inactive chips get light gray background
- Helper text: "The preset used when you trigger a correction via the review hotkey."

**Behavior**
- Launch at login toggle with description subtitle

**Status** (collapsible, collapsed by default)
- Server health: green/red dot + "Healthy" / "Error"
- Accessibility permission: green/red dot + "Granted" / "Not Granted" (with "Open System Settings" link if not granted)
- Active model name

### 2. Models

Model management with download/delete capabilities.

**First-use nudge banner**
- Shown when zero models are downloaded
- Green gradient background, download icon
- Text: "Download a model to get started" with recommendation for Gemma 4 E4B
- Disappears once any model is downloaded

**Model list**
- One row per model from `shared/models.json`
- Each row shows:
  - Model name (bold) + badges (Recommended, Default, Ready, Downloading)
  - Subtitle: parameter count, file size, RAM requirement
  - Action button: Download / Cancel / Delete
- States per model:
  - **Not downloaded**: neutral row, "Download" button
  - **Downloading**: amber "Downloading" badge, progress bar (green gradient, 4px height), bytes/total + percentage text, "Cancel" button
  - **Ready**: green "Ready" badge, row has faint green background tint. "Delete" button (red text)
  - **Default**: solid green "Default" badge (only on the model selected as default in the General tab)
- Default model is set from the General tab only (not from the Models tab) to keep a single place for that choice
- Cannot delete the currently active/default model — button disabled with tooltip

**Storage footer**
- Right-aligned: "X.X GB used by models"

### 3. Cloud

Only relevant when backend is set to "Cloud (Vercel AI Gateway)" in General.

**When Local is active:**
- Dimmed section with message: "Switch to Cloud backend in General to configure."

**When Cloud is active:**
- API Key: secure text field (masked by default, toggle to reveal)
- "Test Connection" button: hits server health check through cloud backend
- Connection status indicator: Untested (gray) / Connected (green dot) / Failed (red dot + error message)
- API key stored in macOS Keychain, not UserDefaults

### 4. Hotkeys

Each action gets a row with a dropdown picker of predefined key combinations.

| Action | Default | Alternatives |
|--------|---------|-------------|
| Review (command palette) | Cmd+Shift+G | Cmd+Shift+R, Ctrl+Shift+G, Cmd+Shift+; |
| Autofix | Cmd+Shift+Option+G | Cmd+Shift+Option+R, Ctrl+Shift+Option+G |
| Fix (direct) | Option+Shift+Cmd+G | Option+Shift+Cmd+F, Ctrl+Shift+F |
| Paraphrase (direct) | Option+Shift+Cmd+P | Option+Shift+Cmd+H, Ctrl+Shift+P |
| Professional (direct) | Option+Shift+Cmd+M | Option+Shift+Cmd+J, Ctrl+Shift+M |

- Conflict detection: if two actions share the same combo, show inline warning and prevent saving
- "Reset to Defaults" button at the bottom
- Changes take effect immediately (GlobalHotkeyManager re-registers on change)

### 5. Dictionary

Carries forward the existing dictionary UI, restyled to match:

- Text field + "Add" button at the top
- Scrollable word list with remove buttons per word
- Same server API: `GET/POST/DELETE /dictionary`
- No functional changes, only visual alignment

## Visual Style

Native macOS settings window with Panini accents (approach B from brainstorming):

- **Window**: SwiftUI `Settings` scene, standard macOS tab bar
- **Tab indicator**: green underline on active tab (Panini accent green: `#4c8f52`)
- **Section headers**: Georgia serif, 11px, uppercase, letter-spacing 0.5px, warm gray (`#8a8478`)
- **Content groups**: white background cards with 10px border-radius, 1px `#ddd` border
- **Controls**: native macOS toggles, pickers, and text fields — no custom controls except preset pills and model cards
- **Preset pills**: capsule shape, 20px border-radius. Active: green fill `#e8f5e9`, green border, dark green text. Inactive: light gray
- **Status dots**: 7px circles, green `#4c8f52` for healthy, red for error
- **Model badges**: small uppercase, 4px border-radius. Recommended: green outline. Default: solid green. Ready: green outline. Downloading: amber
- **Progress bars**: 4px height, rounded, green gradient (`#8bc34a` to `#4caf50`)
- **Destructive actions**: red text on delete buttons, no red backgrounds
- **Dark mode**: follows system — uses existing `ReviewPanelTheme.dark` color values as reference for accent adaptation

## What's NOT in scope

- Custom key recorder (full hotkey customization) — deferred, predefined options only for now
- Onboarding/first-launch wizard — the nudge banner on the Models tab handles first-use guidance
- Cloud provider presets beyond Vercel AI Gateway
- Runtime server config updates — server restarts on backend/model change
- Appearance/theme settings — follows system dark/light mode
- Custom presets — only the five built-in presets are selectable
