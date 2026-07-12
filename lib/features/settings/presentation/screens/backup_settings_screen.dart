import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/backup/backup_conflict_dialog.dart';
import '../../../../features/backup/backup_service.dart';
import '../../../../features/backup/backup_upload_pipeline.dart';
import '../../../../features/backup/local_backup_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF2F6F5E);
const _kBg = Color(0xFFFFFBF1);

enum _MenuAction { restore, changeFolder }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BackupSettingsScreen extends StatefulWidget {
  final AppCubit cubit;

  const BackupSettingsScreen({
    super.key,
    required this.cubit,
  });

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  GoogleSignInAccount? _account;
  bool loading = false;

  bool _accountLoading = true;
  Future<void>? _accountFuture;

  // A — auto cloud
  bool _autoCloudCardLoading = true;
  bool _autoCloudEnabled = false;
  String? _lastAutoCloudAt;
  String _autoCloudStatus = 'unknown';

  // B — auto local
  bool _autoLocalCardLoading = true;
  bool _autoLocalEnabled = false;
  String? _autoLocalFolder;
  String? _lastAutoLocalAt;

  // C — manual cloud
  bool _manualCloudCardLoading = true;
  String? _lastManualCloudAt;
  int? _lastManualCloudBytes;

  // D — manual local
  bool _manualLocalCardLoading = true;
  String? _manualLocalFolder;
  String? _lastManualLocalAt;
  int _manualLocalCount = 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // Init / data loading
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _ensureAccount();
    _loadAutoCloudCard();
    _loadAutoLocalCard();
    _loadManualCloudCard();
    _loadManualLocalCard();
  }

  Future<void> _ensureAccount() =>
      _accountFuture ??= _loadAccount();

  Future<void> _loadAccount() async {
    _account = _googleSignIn.currentUser;
    _account ??= await _googleSignIn.signInSilently();
    if (_account != null) await _signInFirebaseWithGoogle(_account!);
    if (mounted) setState(() => _accountLoading = false);
  }

  Future<void> _refreshAccount() {
    _accountFuture = _loadAccount();
    return _accountFuture!;
  }

  Future<void> _loadAutoCloudCard() async {
    if (mounted) setState(() => _autoCloudCardLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _autoCloudEnabled = prefs.getBool('auto_cloud_backup_enabled') ?? false;
    _lastAutoCloudAt = prefs.getString('last_auto_cloud_backup_at');
    _autoCloudStatus = prefs.getString('last_auto_cloud_status') ?? 'unknown';
    if (mounted) setState(() => _autoCloudCardLoading = false);
  }

  Future<void> _loadAutoLocalCard() async {
    if (mounted) setState(() => _autoLocalCardLoading = true);
    _autoLocalEnabled = await LocalBackupService.autoEnabled();
    _autoLocalFolder = await LocalBackupService.autoFolder();
    _lastAutoLocalAt = await LocalBackupService.lastAutoBackupAt();
    if (mounted) setState(() => _autoLocalCardLoading = false);
  }

  Future<void> _loadManualCloudCard() async {
    if (mounted) setState(() => _manualCloudCardLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _lastManualCloudAt = prefs.getString('last_manual_cloud_backup_at');
    await _ensureAccount();
    if (_account != null) {
      try {
        final meta = await BackupService.fetchSlotMetadata(
          _account!.email,
          BackupSlot.manualCloud,
        );
        _lastManualCloudBytes = meta?['byteSize'] as int?;
      } catch (_) {}
    }
    if (mounted) setState(() => _manualCloudCardLoading = false);
  }

  Future<void> _loadManualLocalCard() async {
    if (mounted) setState(() => _manualLocalCardLoading = true);
    _manualLocalFolder = await LocalBackupService.manualFolder();
    _lastManualLocalAt = await LocalBackupService.lastManualBackupAt();
    _manualLocalCount = (await LocalBackupService.manualFiles()).length;
    if (mounted) setState(() => _manualLocalCardLoading = false);
  }

  Future<void> _refreshAll() => Future.wait([
        _refreshAccount(),
        _loadAutoCloudCard(),
        _loadAutoLocalCard(),
        _loadManualCloudCard(),
        _loadManualLocalCard(),
      ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // Smart time formatting
  // ═══════════════════════════════════════════════════════════════════════════

  static const _weekdays = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت',
  ];

  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String _hhmm(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? "م" : "ص"}';
  }

  String _smartTime(String? iso, AppLocalizations l) {
    if (iso == null) return l.backupNever;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return l.backupNever;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dtStart = DateTime(dt.year, dt.month, dt.day);
    final dayDiff = todayStart.difference(dtStart).inDays;
    final t = _hhmm(dt);
    if (dayDiff == 0) return '${l.backupTimeToday} • $t';
    if (dayDiff == 1) return '${l.backupTimeYesterday} • $t';
    if (dayDiff < 7) return '${_weekdays[dt.weekday % 7]} • $t';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  static String _shortPath(String? path) {
    if (path == null || path.isEmpty) return '—';
    final parts = path
        .split(RegExp(r'[/\\]'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 2) return parts.join(' / ');
    return '${parts[parts.length - 2]} / ${parts.last}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _signInFirebaseWithGoogle(GoogleSignInAccount account) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email == account.email) return;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  bool _guardAuth(AppLocalizations l) {
    if (_account == null) {
      _msg(l.backupMsgSignInFirst);
      return false;
    }
    if (FirebaseAuth.instance.currentUser?.email != _account!.email) {
      _msg(l.backupMsgReAuth);
      return false;
    }
    return true;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<String?> _pickFolder() async {
    final ok = await _requestStoragePermission();
    if (!ok) return null;
    return FilePicker.getDirectoryPath();
  }

  Future<bool> _confirm(String title, String body, AppLocalizations l) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.backupConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            child: Text(l.backupConfirmProceed),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // A) Auto cloud
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleAutoCloud(bool value) async {
    final l = AppLocalizations.of(context);
    if (value && !_guardAuth(l)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_cloud_backup_enabled', value);
    if (mounted) setState(() => _autoCloudEnabled = value);
  }

  Future<void> _restoreAutoCloudBackup() async {
    final l = AppLocalizations.of(context);
    if (!_guardAuth(l)) return;
    final ok = await _confirm(l.backupConfirmTitle, l.backupConfirmBody, l);
    if (!ok) return;
    setState(() => loading = true);
    try {
      final email = _account!.email;
      final slot = await BackupService.latestAutoSlot(email);
      String? json;
      if (slot != null) json = await BackupService.fetchSlotData(email, slot);
      json ??= await BackupService.fetchLegacyData(email);
      if (json == null) { _msg(l.backupNoBackupFound); return; }
      await widget.cubit.importStateJson(json);
      _msg(l.backupMsgRestored);
    } catch (e) {
      _msg('${l.backupError}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // B) Auto local
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleAutoLocal(bool value) async {
    if (value && _autoLocalFolder == null) {
      final picked = await _pickFolder();
      if (picked == null) return;
      await LocalBackupService.setAutoFolder(picked);
      if (mounted) setState(() => _autoLocalFolder = picked);
    }
    await LocalBackupService.setAutoEnabled(value);
    if (mounted) setState(() => _autoLocalEnabled = value);
  }

  Future<void> _changeAutoLocalFolder() async {
    final picked = await _pickFolder();
    if (picked == null) return;
    await LocalBackupService.setAutoFolder(picked);
    if (mounted) setState(() => _autoLocalFolder = picked);
    final l = AppLocalizations.of(context);
    _msg(l.backupMsgFolderChanged);
  }

  Future<void> _restoreAutoLocalBackup() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.backupConfirmTitle, l.backupConfirmBody, l);
    if (!ok) return;
    setState(() => loading = true);
    try {
      final file = await LocalBackupService.latestAutoFile();
      if (file == null) { _msg(l.backupNoBackupFound); return; }
      await widget.cubit.importStateJson(await file.readAsString());
      _msg(l.backupMsgRestored);
    } catch (e) {
      _msg('${l.backupError}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // C) Manual cloud
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _createManualCloudBackup() async {
    final l = AppLocalizations.of(context);
    if (!_guardAuth(l)) return;
    setState(() => loading = true);
    try {
      final result = await BackupUploadPipeline.run(
        email: _account!.email,
        displayName: _account!.displayName ?? '',
        localState: widget.cubit.state,
        exportJson: widget.cubit.exportStateJson,
        kind: BackupKind.manual,
        onMerge: widget.cubit.mergeStateJson,
        resolveConflict: ({
          required remoteTxCount,
          required localTxCount,
          required remoteUpdatedAt,
        }) {
          if (!mounted) return Future.value(BackupConflictChoice.cancel);
          return BackupConflictDialog.show(
            context,
            remoteTxCount: remoteTxCount,
            localTxCount: localTxCount,
            remoteUpdatedAt: remoteUpdatedAt,
          );
        },
      );
      switch (result.status) {
        case BackupUploadStatus.uploaded:
          final now = DateTime.now().toIso8601String();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_manual_cloud_backup_at', now);
          if (mounted) setState(() => _lastManualCloudAt = now);
          await _loadManualCloudCard();
          _msg(l.backupMsgSaved);
          break;
        case BackupUploadStatus.cancelled:
          break;
        default:
          _msg(result.message ?? l.backupMsgUploadFailed);
      }
    } catch (e) {
      _msg('${l.backupError}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _restoreManualCloudBackup() async {
    final l = AppLocalizations.of(context);
    if (!_guardAuth(l)) return;
    final ok = await _confirm(l.backupConfirmTitle, l.backupConfirmBody, l);
    if (!ok) return;
    setState(() => loading = true);
    try {
      final email = _account!.email;
      var json = await BackupService.fetchSlotData(email, BackupSlot.manualCloud);
      json ??= await BackupService.fetchLegacyData(email);
      if (json == null) { _msg(l.backupNoBackupFound); return; }
      await widget.cubit.importStateJson(json);
      _msg(l.backupMsgRestored);
    } catch (e) {
      _msg('${l.backupError}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // D) Manual local
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _changeManualLocalFolder() async {
    final picked = await _pickFolder();
    if (picked == null) return;
    await LocalBackupService.setManualFolder(picked);
    if (mounted) setState(() => _manualLocalFolder = picked);
    final l = AppLocalizations.of(context);
    _msg(l.backupMsgFolderChanged);
  }

  Future<void> _createManualLocalBackup() async {
    var folder = _manualLocalFolder;
    if (folder == null) {
      folder = await _pickFolder();
      if (folder == null) return;
      await LocalBackupService.setManualFolder(folder);
      if (mounted) setState(() => _manualLocalFolder = folder);
    }
    final ok = await LocalBackupService.writeManual(
      widget.cubit.exportStateJson(), folder);
    final l = AppLocalizations.of(context);
    if (ok) {
      final now = await LocalBackupService.lastManualBackupAt();
      final count = (await LocalBackupService.manualFiles()).length;
      if (mounted) setState(() { _lastManualLocalAt = now; _manualLocalCount = count; });
      _msg(l.backupMsgSaved);
    } else {
      _msg(l.backupMsgUploadFailed);
    }
  }

  Future<void> _restoreManualLocalBackup() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.backupConfirmTitle, l.backupConfirmBody, l);
    if (!ok) return;
    setState(() => loading = true);
    try {
      final file = await LocalBackupService.manualFile();
      if (file == null) { _msg(l.backupNoBackupFound); return; }
      await widget.cubit.importStateJson(await file.readAsString());
      _msg(l.backupMsgRestored);
    } catch (e) {
      _msg('${l.backupError}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Google sign-in
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _signIn() async {
    final l = AppLocalizations.of(context);
    setState(() => loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _account = account;
        await _signInFirebaseWithGoogle(account);
        if (mounted) setState(() {});
      }
    } catch (e) {
      _msg('${l.backupMsgSignInFailed}: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    if (mounted) setState(() => _account = null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l.backupTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: _kGreen,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // ── Local section ─────────────────────────────────────────────
            _SectionContainer(
              icon: Icons.folder_outlined,
              title: l.backupLocalSection,
              children: [
                _BackupCard(
                  title: l.backupAutomatic,
                  loading: _autoLocalCardLoading,
                  control: Switch(
                    value: _autoLocalEnabled,
                    activeColor: _kGreen,
                    onChanged: _toggleAutoLocal,
                  ),
                  menuActions: [_MenuAction.restore, _MenuAction.changeFolder],
                  onMenuAction: (a) {
                    if (a == _MenuAction.restore) _restoreAutoLocalBackup();
                    if (a == _MenuAction.changeFolder) _changeAutoLocalFolder();
                  },
                  folderPath: _shortPath(_autoLocalFolder),
                  timeStr: _smartTime(_lastAutoLocalAt, l),
                ),
                const _CardDivider(),
                _BackupCard(
                  title: l.backupManual,
                  loading: _manualLocalCardLoading,
                  control: _CompactButton(
                    label: l.backupNow,
                    onTap: _createManualLocalBackup,
                  ),
                  menuActions: [_MenuAction.restore, _MenuAction.changeFolder],
                  onMenuAction: (a) {
                    if (a == _MenuAction.restore) _restoreManualLocalBackup();
                    if (a == _MenuAction.changeFolder) _changeManualLocalFolder();
                  },
                  folderPath: _shortPath(_manualLocalFolder),
                  timeStr: _smartTime(_lastManualLocalAt, l),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Cloud section ─────────────────────────────────────────────
            _SectionContainer(
              icon: Icons.cloud_outlined,
              title: l.backupCloudSection,
              children: [
                _AccountRow(
                  account: _account,
                  loading: _accountLoading,
                  onSignIn: _signIn,
                  onSignOut: _signOut,
                ),
                const _CardDivider(),
                _BackupCard(
                  title: l.backupAutomatic,
                  loading: _autoCloudCardLoading,
                  control: Switch(
                    value: _autoCloudEnabled,
                    activeColor: _kGreen,
                    onChanged: _toggleAutoCloud,
                  ),
                  menuActions: [_MenuAction.restore],
                  onMenuAction: (a) {
                    if (a == _MenuAction.restore) _restoreAutoCloudBackup();
                  },
                  timeStr: '${l.backupLastBackup}: ${_smartTime(_lastAutoCloudAt, l)}',
                ),
                const _CardDivider(),
                _BackupCard(
                  title: l.backupManual,
                  loading: _manualCloudCardLoading,
                  control: _CompactButton(
                    label: l.backupNow,
                    onTap: _createManualCloudBackup,
                  ),
                  menuActions: [_MenuAction.restore],
                  onMenuAction: (a) {
                    if (a == _MenuAction.restore) _restoreManualCloudBackup();
                  },
                  timeStr: '${l.backupLastBackup}: ${_smartTime(_lastManualCloudAt, l)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionContainer
// ─────────────────────────────────────────────────────────────────────────────

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kGreen.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _kGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF1A2B25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _CardDivider(),
          ...children,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BackupCard
// ─────────────────────────────────────────────────────────────────────────────

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.title,
    required this.loading,
    required this.control,
    required this.menuActions,
    required this.onMenuAction,
    required this.timeStr,
    this.folderPath,
  });

  final String title;
  final bool loading;
  final Widget control;
  final List<_MenuAction> menuActions;
  final void Function(_MenuAction) onMenuAction;
  final String timeStr;
  final String? folderPath;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1A2B25),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _kGreen,
                  ),
                )
              else
                control,
              _CardMenu(
                actions: menuActions,
                onSelected: onMenuAction,
                l: l,
              ),
            ],
          ),
          // ── Metadata row ───────────────────────────────────────────────
          if (!loading) ...[
            const SizedBox(height: 7),
            if (folderPath != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetaChip(Icons.access_time_rounded, timeStr),
                  _MetaChip(Icons.folder_outlined, folderPath!),
                ],
              )
            else
              _MetaChip(Icons.access_time_rounded, timeStr),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AccountRow
// ─────────────────────────────────────────────────────────────────────────────

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.loading,
    required this.onSignIn,
    required this.onSignOut,
  });

  final GoogleSignInAccount? account;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: loading
                ? Text(
                    l.backupCheckingAccount,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8279),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    account?.email ?? l.backupNotSignedIn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: account != null
                          ? const Color(0xFF1A2B25)
                          : const Color(0xFF8A8279),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _kGreen,
              ),
            )
          else if (account != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.backupConnected,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onSignOut,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8A8279),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.backupSignOut,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            FilledButton(
              onPressed: onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l.backupSignInGoogle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompactButton
// ─────────────────────────────────────────────────────────────────────────────

class _CompactButton extends StatelessWidget {
  const _CompactButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _kGreen,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CardMenu
// ─────────────────────────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.actions,
    required this.onSelected,
    required this.l,
  });

  final List<_MenuAction> actions;
  final void Function(_MenuAction) onSelected;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFFB0A899),
        size: 18,
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final action in actions)
          PopupMenuItem<_MenuAction>(
            value: action,
            child: Text(
              action == _MenuAction.restore
                  ? l.backupMenuRestore
                  : l.backupMenuChangeFolder,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: action == _MenuAction.restore
                    ? _kGreen
                    : const Color(0xFF1A2B25),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetaChip  — icon + small label
// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFFB0A899)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF9A9088),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CardDivider
// ─────────────────────────────────────────────────────────────────────────────

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFEEEAE2),
    );
  }
}
