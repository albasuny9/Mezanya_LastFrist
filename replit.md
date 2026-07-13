# Mezanya - Personal Financial Management App

## Overview
Mezanya is a Flutter-based personal finance management mobile/web application with Arabic UI. It tracks income, expenses, budgets, and savings through a "jars" and "wallets" system.

## Tech Stack
- **Framework**: Flutter (SDK >=3.3.0 <4.0.0)
- **State Management**: BLoC/Cubit pattern (centralized `AppCubit`)
- **Local Storage**: SharedPreferences (monolithic JSON state)
- **Cloud (optional)**: Firebase Auth, Firestore, Storage — used only for optional cloud backup and profile photo upload
- **UI**: Material Design with Arabic (RTL) locale, IBM Plex Sans Arabic font

## Project Structure
- `lib/` — Flutter source code
  - `lib/main.dart` — Entry point, Firebase initialization
  - `lib/app.dart` — Root app widget
  - `lib/core/` — DI bootstrap, themes, global config
  - `lib/features/` — Feature modules (app_state, app_shell, budget, transactions, wallets, home, logs, settings)
  - `lib/firebase_options.dart` — Firebase configuration
- `web/` — Flutter web entry files (index.html, manifest, icons)
- `build/web/` — Compiled Flutter web output (served in production)
- `serve.py` — Python HTTP server serving the compiled web build on port 5000
- `build_web.sh` — Script to compile Flutter web and patch flutter_bootstrap.js

## How to Run
The workflow runs `python3 serve.py` which serves `build/web/` on port 5000.

**To rebuild after code changes:**
```bash
bash build_web.sh
```
Then restart the "Start application" workflow.

## Key Features
- Multi-wallet support (cash, bank accounts)
- Budget jar allocation system
- Income routing and expense tracking
- Recurring transaction automation
- Savings goals
- Audit log of all financial changes
- Optional Firebase cloud backup
- Optional Google Sign-In and email/password auth for backup sync

## Firebase
Firebase is configured in `lib/firebase_options.dart`. It is used optionally — the app works fully offline with local SharedPreferences storage. Firebase features (auth, cloud backup, profile photo upload) are opt-in from the Settings screen.

## User preferences
- Agent role is restricted to **senior code analyst / auditor** for this project: audit only, produce reports and implementation plans, do not modify code unless explicitly asked.
- Never modify financial logic, backup logic, transaction processing, or app architecture.
- Audit focus areas: duplicated code, dead code, unused imports, large widgets/long methods, architectural violations, repeated UI components, repeated strings, magic numbers, files that should be split, localization opportunities, performance issues.
- Every recommendation in a report must include: Why, Risk level, Files affected, Estimated implementation effort.
- Do not rely on agent persistent memory for project architecture knowledge. The repository documentation (this file and `docs/architecture/`) is the only long-term source of truth — durable architectural findings must be written there, not only in memory.

## Notes
- The web build uses local CanvasKit (not CDN) for offline rendering
- Service worker is disabled to avoid stale cache issues in Replit preview
- The app falls back to CPU-only rendering when WebGL is unavailable
