---
name: flutter gen-l10n Replit quirk
description: flutter gen-l10n exits with code 1 on this Replit instance but the .dart files are written correctly — safe to ignore.
---

## Rule
`flutter gen-l10n` crashes at the `dart format` step (missing `flutter_lints-6.0.0/lib/flutter.yaml`), but the three generated files are written **before** formatting runs:
- `lib/l10n/generated/app_localizations.dart`
- `lib/l10n/generated/app_localizations_ar.dart`
- `lib/l10n/generated/app_localizations_en.dart`

The crash is a non-fatal format step. The files compile fine.

**Why:** `dart format` attempts to read `analysis_options.yaml` which includes `package:flutter_lints/flutter.yaml`, but that package isn't cached in the Replit pub-cache for this SDK version.

**How to apply:** After running `flutter gen-l10n`, ignore the exit-1 error and verify the three generated files exist before proceeding. Never re-run gen-l10n in a loop trying to fix the crash — it always crashes at format but always writes the files.
