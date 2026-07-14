# BUG-004 — Auto Cloud Backup Real-Device Verification (Static Code Trace)

**Investigation Target:** Confirm whether automatic cloud backup fires without the user opening backup settings, ahead of the required real-device verification.
**Mode:** Forensic investigation only. No code was modified. No fix is proposed. **This document covers only the static code trace — the Bug Backlog's required real-device test was not performed and cannot be performed by static investigation (see Unknowns/Next Investigation).**

---

## Executive Summary

The current code is already written to attempt an automatic cloud backup after every state-mutating action, independent of whether the user ever opens the backup/settings screen in that session. `AppCubit._autoSync` runs on every `_applyAndLog` call (i.e. after essentially every transaction/log-producing action) and, for the cloud path, first calls `_ensureFirebaseBridged()`, which performs a **silent** Google sign-in (`GoogleSignIn.signInSilently()`, no UI) to restore a Firebase session if one isn't already active, before attempting the actual upload via `BackupUploadPipeline.run(kind: BackupKind.auto)`. A code comment on `_ensureFirebaseBridged` explicitly states this silent-bridge step was added specifically to fix the historical bug where auto cloud backup never worked in sessions where the user didn't visit the settings screen. This is consistent with the Bug Backlog's note that "the bridge and lifecycle fixes" already landed and only a real-device confirmation remains.

**This document cannot itself supply that confirmation.** Whether `signInSilently()` actually succeeds depends on real platform state (a previously-granted Google session cached by the OS/browser) that only exists on an actual device/browser profile with a prior sign-in — it cannot be exercised or observed from static source reading alone.

---

## Investigation Scope

- Traced only the automatic (non-interactive) backup path (`BackupKind.auto`), not the manual/interactive backup UI.
- Files read directly: `app_cubit.dart` (`_applyAndLog`, `_ensureFirebaseBridged`, `_autoSync`), `local_backup_service.dart` (`writeAuto`), `backup_upload_pipeline.dart` (`run`, `BackupUploadStatus`/`BackupKind`).
- Did not read `backup_upload_pipeline.dart` past line 70 (conflict-detection/upload stages) or `backup_conflict_dialog.dart` — not required to answer the specific "does it fire automatically" question in scope.
- Did not attempt any device/emulator test — out of scope for a static, read-only investigation.

---

## Execution Flow

### 1. Every state-mutating cubit action ends in `_autoSync`

```dart
// lib/features/app_state/presentation/cubits/app_cubit.dart:339-346 (_applyAndLog, tail)
final next = nextRaw.copyWith(
  logs: [log, ...nextRaw.logs].take(600).toList(),
  notifications: notifications,
);
await _repository.saveState(next);
emit(next);
_autoSync(next);
```

`_applyAndLog` is the shared helper used by `addTransaction`, `deleteTransaction`, `updateBudgetSetup`, and effectively every other mutating method in `AppCubit` (confirmed by its use throughout the file for the `apply:` callback pattern seen in the BUG-001 investigation). Every one of those calls ends by invoking `_autoSync(next)` — there is no manual step or settings-screen visit required to reach this call.

### 2. `_autoSync` — cloud path fires independently of local path, gated only by a stored preference flag and a live Firebase session

```dart
// app_cubit.dart:377-414
void _autoSync(AppStateEntity appState) {
  _ensureFirebaseBridged().then((_) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    SharedPreferences.getInstance().then((prefs) {
      final enabled = prefs.getBool('auto_cloud_backup_enabled') ?? false;
      if (!enabled) return;
      BackupUploadPipeline.run(
        email: user.email!,
        displayName: user.displayName ?? user.email!,
        localState: appState,
        exportJson: () => jsonEncode(appState.toMap()),
        kind: BackupKind.auto,
      )...
    })...
  })...

  LocalBackupService.autoEnabled().then((enabled) {
    if (!enabled || appState.isEmpty) return;
    LocalBackupService.writeAuto(jsonEncode(appState.toMap()));
  })...
}
```

The cloud branch and the local branch are two independent `.then()` chains started from the same `_autoSync` call — a failure or a no-op in one does not block the other (confirmed by the trailing code comment at line 413: `"لو السحابة مش متاحة أو تم تأجيل الرفع، مش بيوقف الـ app"` — "if the cloud isn't available or the upload was deferred, it doesn't stop the app"). The cloud branch requires, in order: (a) `_ensureFirebaseBridged()` to resolve, (b) a non-null `FirebaseAuth.instance.currentUser` with a non-null `email` immediately after, (c) the `auto_cloud_backup_enabled` SharedPreferences flag to be `true`.

### 3. `_ensureFirebaseBridged` — the specific fix for "works only after opening settings"

```dart
// app_cubit.dart:348-375
/// ... يضمن وجود جلسة Firebase موثَّقة قبل أي رفع تلقائي، بدون الاعتماد
/// على زيارة المستخدم لأي شاشة إعدادات في نفس الجلسة (كان هذا السبب
/// الجذري لعدم عمل النسخ التلقائي السحابي إطلاقًا في الجلسات التي لا
/// تُفتح فيها شاشة الإعدادات — راجع تحقيق الباگ في نفس هذا الالتزام).
/// يستخدم `signInSilently()` (استرجاع صامت لجلسة Google محفوظة، بلا
/// أي واجهة) — إن لم توجد جلسة، يخرج بأمان بلا أثر.
Future<void> _ensureFirebaseBridged() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    final account =
        googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    if (account == null) return;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (_) {
    // فشل الجسر — الرفع التلقائي هيتخطى هذه الدورة بأمان، زي حالة
    // عدم وجود مستخدم مسجَّل من الأساس.
  }
}
```

Translated comment (lines 352-357): "Ensures a verified Firebase session exists before any automatic upload, without depending on the user visiting any settings screen in the same session (this was the root cause of automatic cloud backup never working at all in sessions where the settings screen isn't opened — see the bug investigation in this same commit)." This is a direct, in-repo statement that a prior fix specifically targeted the "must open settings first" symptom, by using `signInSilently()` to recover a previously-granted Google session without any UI prompt. If `currentUser` is already set (i.e., the user is mid-session-signed-in already), the bridge short-circuits at line 359 and does nothing further.

### 4. Local auto backup — for contrast, has no session/bridge dependency

```dart
// local_backup_service.dart:103-114 (writeAuto)
static Future<bool> writeAuto(String json) async {
  final folder = await autoFolder();
  if (folder == null) return false;
  final target = File('$folder${Platform.pathSeparator}$_autoFileName');
  final ok = await _writeSafely(target, json);
  ...
}
```

Local backup only depends on filesystem access (`autoFolder()`) and the `auto_local_backup_enabled` preference (checked in `_autoSync` via `LocalBackupService.autoEnabled()`) — no Firebase/Google session is involved, which is consistent with the Bug Backlog's note that "local auto backup works" while only the cloud path needed the bridge fix.

### 5. `BackupUploadPipeline.run` — the actual upload, once a session and the enabled flag both pass

```dart
// backup_upload_pipeline.dart:57-70 (entry + first validation stage)
static Future<BackupUploadResult> run({
  required String email,
  required String displayName,
  required AppStateEntity localState,
  required String Function() exportJson,
  required BackupKind kind,
  ...
}) async {
  // المرحلة 1: التحقق (Validation) — قبل أي اتصال بالشبكة.
  if (localState.isEmpty) {
    return const BackupUploadResult(BackupUploadStatus.rejectedEmpty, ...);
  }
  ...
```

The pipeline itself is a single shared entry point for both manual and automatic uploads (per its class doc comment, lines 42-47, and the referenced `ADR-0003: docs/architecture/adr/0003-backup-versioning-overwrite-protection.md`), gated first by a local-state emptiness check before any network call. This confirms the automatic path reaches real upload logic once Sections 2-3's preconditions are satisfied — the remaining stages (conflict detection, actual Firestore write) were not traced further, as they are not relevant to the specific "does it fire automatically" question in scope.

---

## Evidence

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Does cloud auto backup require the user to open the settings screen in the current session? | No, by code design — `_ensureFirebaseBridged` explicitly exists to remove that dependency via silent Google sign-in. | `app_cubit.dart:348-375`, comment at lines 352-357. |
| 2 | Is the cloud auto-backup call reachable after an ordinary transaction (not just from a settings screen)? | Yes — `_autoSync` is called from `_applyAndLog`, the shared tail of essentially all state-mutating `AppCubit` methods, including `addTransaction`. | `app_cubit.dart:339-346`. |
| 3 | What gates whether the upload actually happens? | Three preconditions in order: (a) `_ensureFirebaseBridged()` must resolve to a signed-in `FirebaseAuth.instance.currentUser` with a non-null email, (b) the `auto_cloud_backup_enabled` SharedPreferences flag must be `true`, (c) `BackupUploadPipeline.run`'s own internal validation (e.g. non-empty local state) must pass. | `app_cubit.dart:378-390`; `backup_upload_pipeline.dart:66-70`. |
| 4 | Can this precondition chain be confirmed to succeed on a real device without this investigation's tools? | Not proven here — `signInSilently()`'s success depends on OS/browser-level cached Google session state that only exists on an actual device with a prior real sign-in; this cannot be observed or simulated by reading source code. | `app_cubit.dart:361-364` (the actual `signInSilently()` call). |

---

## Root Cause

Not applicable in the traditional sense — this is not a symptom investigation but a pre-verification code trace requested by the Task Plan before a manual device test. The static evidence shows the code is **already designed and, per an in-repo comment, already fixed** to perform automatic cloud backup without requiring a settings-screen visit, via a silent-sign-in bridge (`_ensureFirebaseBridged`) inserted ahead of every automatic upload attempt (`_autoSync`). No gap or regression in this specific mechanism was found in this trace.

---

## Confirmed Facts

- `_autoSync` is invoked after `_applyAndLog`, i.e., after essentially every `AppCubit` state mutation (transactions, budget edits, etc.), with no dependency on any UI screen having been opened in the session.
- The cloud-backup branch of `_autoSync` calls `_ensureFirebaseBridged()` before checking `FirebaseAuth.instance.currentUser`, and `_ensureFirebaseBridged` uses `GoogleSignIn.signInSilently()` — a non-interactive call that requires no user action and shows no UI.
- A trailing code comment explicitly states this bridge was added to fix a previously-confirmed root cause: automatic cloud backup not working at all in sessions where the settings screen was never opened.
- The local-backup branch (`LocalBackupService.writeAuto`) has no session/bridge dependency, confirming it is architecturally independent of the cloud branch, consistent with the Bug Backlog's "local works, cloud needs verification" framing.
- `BackupUploadPipeline.run` is the single shared upload entry point for both manual and automatic kinds, per its own doc comment and referenced ADR-0003.

## Likely Causes

- Not applicable — no unresolved symptom was found in this static trace to attribute a "likely cause" to. If the pending real-device test reveals the upload still doesn't happen, the most likely failure point based on this trace would be `signInSilently()` returning `null` on the specific test device (e.g., no cached Google session, revoked grant, or platform-specific silent-sign-in restrictions) — **not proven**, since this requires the device test itself to observe.

---

## Unknowns

- **Not proven:** whether `signInSilently()` actually succeeds on a real target device/browser after a prior explicit sign-in — this is exactly the real-device verification the Bug Backlog calls for, and it is outside what a static, read-only code investigation can determine.
- **Not proven:** whether `BackupUploadPipeline.run`'s later stages (conflict detection, actual Firestore write, lines beyond 70) contain any additional gate that could silently prevent the upload even after the bridge and enabled-flag checks pass — not traced in this investigation, as it was scoped to the "does it fire automatically" question only.
- **Not proven:** whether `auto_cloud_backup_enabled` is reliably persisted/read correctly across app restarts on a real device (vs. being reset, e.g., after a fresh install) — only its read-site in `_autoSync` was confirmed, not its full write/lifecycle history.
- **Not proven:** app-lifecycle interaction (backgrounding/foregrounding, app kill mid-upload) — not traced, as the bug report's "Next action" describes a foreground trigger-a-transaction scenario, not a lifecycle-transition scenario.

---

## Files Involved

- `lib/features/app_state/presentation/cubits/app_cubit.dart` (`_applyAndLog`, `_ensureFirebaseBridged`, `_autoSync`)
- `lib/features/backup/local_backup_service.dart` (`writeAuto`, `autoEnabled`)
- `lib/features/backup/backup_upload_pipeline.dart` (`run`, `BackupUploadStatus`, `BackupKind`)
- `docs/architecture/adr/0003-backup-versioning-overwrite-protection.md` (referenced by `BackupUploadPipeline`'s doc comment — not read in this pass)

## Methods Involved

- `AppCubit._applyAndLog` — shared mutation tail, calls `_autoSync`
- `AppCubit._autoSync` — dispatches independent local/cloud auto-backup attempts
- `AppCubit._ensureFirebaseBridged` — silent Google/Firebase session recovery ahead of cloud upload
- `LocalBackupService.writeAuto` — local auto-backup write (contrast, no session dependency)
- `BackupUploadPipeline.run` — shared manual/automatic upload entry point

---

## Next Investigation

(Provided for completeness only — no fix proposed here, per investigation scope.)
- **This is the actual required next step, not merely a suggestion:** perform the real-device test described in the Bug Backlog verbatim — fresh device/session, sign in once interactively so a Google session exists to be recovered silently later, trigger an ordinary transaction in a later session without opening backup settings, and confirm (e.g. via the `last_auto_cloud_status` SharedPreferences key written at `app_cubit.dart:401/404`, or direct Firestore inspection) whether the upload actually completed. This requires the user's own device/account and cannot be performed by static investigation.
- If the device test fails, trace `BackupUploadPipeline.run`'s untraced later stages (conflict detection, actual Firestore write path) as the next static investigation target.
