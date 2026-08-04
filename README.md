# Mezanya (الميزانية)

Mezanya is a Flutter personal-finance app for managing wallets, budget "jars," recurring transactions, and debts, built with a feature-first Clean Architecture and a single centralized `AppCubit` app state.

This root `README.md` is a short pointer only. It is not a source of truth for business rules or architecture decisions — see the documentation map below.

## Where to look

- **Start here as an AI agent:** `.agents/README.md` — mandatory entry point and operating rules for any agent working in this repository.
- **Business rules (sole source of truth):** `docs/architecture/Mezanya Domain Bible/`
- **Architecture decisions:** `docs/architecture/adr/`
- **Documentation index / map:** `.agents/PROJECT_INDEX.md`, `.agents/DOCUMENTATION_MAP.md`
- **Environment, run instructions, and current agent operating protocol:** `replit.md`

## Running the app

1. Install the Flutter SDK.
2. From the project root, install packages:
   - `flutter pub get`
3. Run:
   - `flutter run`

For Replit-specific run/workflow configuration, see `replit.md`.
