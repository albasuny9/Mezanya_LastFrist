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
import '../../../app_state/presentation/cubits/app_cubit.dart';

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
  static const Color _green = Color(0xFF2F6F5E);
  static const Color _bg = Color(0xFFFFFBF1);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  GoogleSignInAccount? _account;
  bool loading = false;

  // النسخ التلقائي السحابي (A)
  bool _autoCloudEnabled = false;
  String? _lastAutoCloudAt;
  String _autoCloudStatus = 'unknown'; // ok | deferred | failed | unknown

  // النسخ التلقائي المحلي (B)
  bool _autoLocalEnabled = false;
  String? _autoLocalFolder;
  String? _lastAutoLocalAt;

  // النسخ اليدوي السحابي (C)
  String? _lastManualCloudAt;

  // النسخ اليدوي المحلي (D)
  String? _manualLocalFolder;
  String? _lastManualLocalAt;

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => loading = true);
    await _loadSettings();
    await _loadGoogle();
    if (mounted) setState(() => loading = false);
  }

  String _formatBackupTime(String? iso) {
    if (iso == null) return 'لم يتم النسخ بعد';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'لم يتم النسخ بعد';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _loadGoogle() async {
    _account = _googleSignIn.currentUser;
    _account ??= await _googleSignIn.signInSilently();
    if (_account != null) {
      await _signInFirebaseWithGoogle(_account!);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCloudEnabled = prefs.getBool('auto_cloud_backup_enabled') ?? false;
    _lastAutoCloudAt = prefs.getString('last_auto_cloud_backup_at');
    _autoCloudStatus = prefs.getString('last_auto_cloud_status') ?? 'unknown';
    _lastManualCloudAt = prefs.getString('last_manual_cloud_backup_at');

    _autoLocalEnabled = await LocalBackupService.autoEnabled();
    _autoLocalFolder = await LocalBackupService.autoFolder();
    _lastAutoLocalAt = await LocalBackupService.lastAutoBackupAt();
    _manualLocalFolder = await LocalBackupService.manualFolder();
    _lastManualLocalAt = await LocalBackupService.lastManualBackupAt();
  }

  bool _guardAuth() {
    if (_account == null) {
      _msg('سجل دخول بجوجل أولًا');
      return false;
    }
    if (FirebaseAuth.instance.currentUser?.email != _account!.email) {
      _msg('أعد تسجيل الدخول بجوجل أولًا');
      return false;
    }
    return true;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // =========================================================================
  // A) النسخ التلقائي السحابي
  // =========================================================================

  Future<void> _toggleAutoCloud(bool value) async {
    if (value && !_guardAuth()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_cloud_backup_enabled', value);
    if (mounted) setState(() => _autoCloudEnabled = value);
  }

  Future<void> _restoreAutoCloudBackup() async {
    if (!_guardAuth()) return;
    final ok = await _confirm(
      'استرجاع النسخة التلقائية السحابية',
      'سيتم استبدال بياناتك الحالية بأحدث نسخة تلقائية محفوظة على السحابة. '
      'هل تريد المتابعة؟',
    );
    if (!ok) return;

    setState(() => loading = true);
    try {
      final email = _account!.email;
      final slot = await BackupService.latestAutoSlot(email);
      String? json;
      if (slot != null) {
        json = await BackupService.fetchSlotData(email, slot);
      }
      // توافق عكسي: لو لا توجد نسخة تلقائية V2 بعد، جرّب النسخة القديمة.
      json ??= await BackupService.fetchLegacyData(email);

      if (json == null) {
        _msg('لا توجد نسخة تلقائية سحابية محفوظة بعد');
        return;
      }
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع من النسخة التلقائية السحابية ✓');
    } catch (e) {
      _msg('فشل الاسترجاع: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =========================================================================
  // B) النسخ التلقائي المحلي
  // =========================================================================

  Future<void> _toggleAutoLocal(bool value) async {
    if (value && _autoLocalFolder == null) {
      final picked = await _pickFolder();
      if (picked == null) return; // لم يُختر مجلد — لا نفعّل بلا مجلد
      await LocalBackupService.setAutoFolder(picked);
      if (mounted) setState(() => _autoLocalFolder = picked);
    }
    await LocalBackupService.setAutoEnabled(value);
    if (mounted) setState(() => _autoLocalEnabled = value);
  }

  Future<String?> _pickFolder() async {
    final ok = await _requestStoragePermission();
    if (!ok) return null;
    return FilePicker.getDirectoryPath();
  }

  Future<void> _changeAutoLocalFolder() async {
    final picked = await _pickFolder();
    if (picked == null) return;
    await LocalBackupService.setAutoFolder(picked);
    if (mounted) setState(() => _autoLocalFolder = picked);
    _msg('تم تغيير مجلد النسخ التلقائي المحلي');
  }

  Future<void> _restoreAutoLocalBackup() async {
    final ok = await _confirm(
      'استرجاع النسخة التلقائية المحلية',
      'سيتم استبدال بياناتك الحالية بأحدث نسخة تلقائية محفوظة على هذا '
      'الجهاز. هل تريد المتابعة؟',
    );
    if (!ok) return;

    setState(() => loading = true);
    try {
      final file = await LocalBackupService.latestAutoFile();
      if (file == null) {
        _msg('لا توجد نسخة تلقائية محلية محفوظة بعد');
        return;
      }
      final json = await file.readAsString();
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع من النسخة التلقائية المحلية ✓');
    } catch (e) {
      _msg('فشل الاسترجاع: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =========================================================================
  // C) النسخ اليدوي السحابي
  // =========================================================================

  Future<void> _createManualCloudBackup() async {
    if (!_guardAuth()) return;
    final appState = widget.cubit.state;

    setState(() => loading = true);
    try {
      final result = await BackupUploadPipeline.run(
        email: _account!.email,
        displayName: _account!.displayName ?? '',
        localState: appState,
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
          _msg('تم إنشاء النسخة اليدوية السحابية ✓');
          break;
        case BackupUploadStatus.cancelled:
          break;
        default:
          _msg(result.message ?? 'تعذّر إنشاء النسخة اليدوية');
      }
    } catch (e) {
      _msg('فشل الرفع: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _restoreManualCloudBackup() async {
    if (!_guardAuth()) return;
    final ok = await _confirm(
      'استرجاع النسخة اليدوية السحابية',
      'سيتم استبدال بياناتك الحالية بالنسخة اليدوية المحفوظة على السحابة. '
      'هل تريد المتابعة؟',
    );
    if (!ok) return;

    setState(() => loading = true);
    try {
      final email = _account!.email;
      var json = await BackupService.fetchSlotData(
        email,
        BackupSlot.manualCloud,
      );
      // توافق عكسي: لو لا توجد نسخة يدوية V2 بعد، جرّب النسخة القديمة.
      json ??= await BackupService.fetchLegacyData(email);

      if (json == null) {
        _msg('لا توجد نسخة يدوية سحابية محفوظة بعد');
        return;
      }
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع من النسخة اليدوية السحابية ✓');
    } catch (e) {
      _msg('فشل الاسترجاع: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =========================================================================
  // D) النسخ اليدوي المحلي
  // =========================================================================

  Future<void> _changeManualLocalFolder() async {
    final picked = await _pickFolder();
    if (picked == null) return;
    await LocalBackupService.setManualFolder(picked);
    if (mounted) setState(() => _manualLocalFolder = picked);
    _msg('تم تغيير مجلد النسخ اليدوي المحلي');
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
      widget.cubit.exportStateJson(),
      folder,
    );
    if (ok) {
      final now = await LocalBackupService.lastManualBackupAt();
      if (mounted) setState(() => _lastManualLocalAt = now);
      _msg('تم إنشاء النسخة اليدوية المحلية ✓');
    } else {
      _msg('فشل إنشاء النسخة اليدوية المحلية');
    }
  }

  Future<void> _restoreManualLocalBackup() async {
    final ok = await _confirm(
      'استرجاع النسخة اليدوية المحلية',
      'سيتم استبدال بياناتك الحالية بالنسخة اليدوية المحفوظة على هذا '
      'الجهاز. هل تريد المتابعة؟',
    );
    if (!ok) return;

    setState(() => loading = true);
    try {
      final file = await LocalBackupService.manualFile();
      if (file == null) {
        _msg('لا توجد نسخة يدوية محلية محفوظة بعد');
        return;
      }
      final json = await file.readAsString();
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع من النسخة اليدوية المحلية ✓');
    } catch (e) {
      _msg('فشل الاسترجاع: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =========================================================================
  // Google sign-in (يخدم كل الأقسام السحابية)
  // =========================================================================

  Future<void> _signIn() async {
    setState(() => loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _account = account;
        await _signInFirebaseWithGoogle(account);
      }
    } catch (e) {
      _msg('فشل تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    if (mounted) setState(() => _account = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'النسخ الاحتياطي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _bootstrap,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _GoogleAccountRow(
                    account: _account,
                    onSignIn: _signIn,
                    onSignOut: _signOut,
                  ),
                  const SizedBox(height: 20),
                  const _SectionHeader('النسخ التلقائي'),
                  const SizedBox(height: 10),
                  _BackupSection(
                    title: 'النسخ التلقائي السحابي',
                    icon: Icons.cloud_sync_rounded,
                    trailing: Switch(
                      value: _autoCloudEnabled,
                      activeColor: _green,
                      onChanged: (v) => _toggleAutoCloud(v),
                    ),
                    rows: [
                      _InfoRow('الحالة', _autoCloudStatusLabel()),
                      _InfoRow(
                        'آخر نسخة ناجحة',
                        _formatBackupTime(_lastAutoCloudAt),
                      ),
                      _InfoRow(
                        'الاحتفاظ',
                        'آخر نسختين تلقائيتين فقط',
                      ),
                    ],
                    actions: [
                      _SecondaryButton(
                        label: 'استرجاع النسخة التلقائية',
                        icon: Icons.restore_rounded,
                        onTap: _restoreAutoCloudBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _BackupSection(
                    title: 'النسخ التلقائي المحلي',
                    icon: Icons.save_rounded,
                    trailing: Switch(
                      value: _autoLocalEnabled,
                      activeColor: _green,
                      onChanged: (v) => _toggleAutoLocal(v),
                    ),
                    rows: [
                      _InfoRow(
                        'آخر نسخة ناجحة',
                        _formatBackupTime(_lastAutoLocalAt),
                      ),
                      _InfoRow(
                        'المجلد الحالي',
                        _autoLocalFolder ?? 'غير محدَّد',
                      ),
                      _InfoRow('الاحتفاظ', 'آخر نسختين تلقائيتين فقط'),
                    ],
                    actions: [
                      _SecondaryButton(
                        label: 'تغيير المجلد التلقائي',
                        icon: Icons.folder_open_rounded,
                        onTap: _changeAutoLocalFolder,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryButton(
                        label: 'استرجاع النسخة التلقائية',
                        icon: Icons.restore_rounded,
                        onTap: _restoreAutoLocalBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader('النسخ اليدوي'),
                  const SizedBox(height: 10),
                  _BackupSection(
                    title: 'النسخ اليدوي السحابي',
                    icon: Icons.cloud_upload_rounded,
                    rows: [
                      _InfoRow(
                        'آخر نسخة يدوية',
                        _formatBackupTime(_lastManualCloudAt),
                      ),
                    ],
                    actions: [
                      _PrimaryButton(
                        label: 'إنشاء نسخة يدوية',
                        icon: Icons.cloud_upload_rounded,
                        onTap: _createManualCloudBackup,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryButton(
                        label: 'استرجاع النسخة اليدوية',
                        icon: Icons.restore_rounded,
                        onTap: _restoreManualCloudBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _BackupSection(
                    title: 'النسخ اليدوي المحلي',
                    icon: Icons.sim_card_download_rounded,
                    rows: [
                      _InfoRow(
                        'آخر نسخة يدوية',
                        _formatBackupTime(_lastManualLocalAt),
                      ),
                      _InfoRow(
                        'المجلد الحالي',
                        _manualLocalFolder ?? 'غير محدَّد',
                      ),
                    ],
                    actions: [
                      _SecondaryButton(
                        label: 'تغيير مجلد التصدير',
                        icon: Icons.folder_open_rounded,
                        onTap: _changeManualLocalFolder,
                      ),
                      const SizedBox(height: 10),
                      _PrimaryButton(
                        label: 'إنشاء نسخة يدوية',
                        icon: Icons.save_alt_rounded,
                        onTap: _createManualLocalBackup,
                      ),
                      const SizedBox(height: 10),
                      _SecondaryButton(
                        label: 'استرجاع النسخة اليدوية',
                        icon: Icons.restore_rounded,
                        onTap: _restoreManualLocalBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String _autoCloudStatusLabel() {
    if (!_autoCloudEnabled) return 'متوقف';
    switch (_autoCloudStatus) {
      case 'ok':
        return 'يعمل';
      case 'deferred':
        return 'بانتظار مراجعة تعارض';
      case 'failed':
        return 'فشل آخر محاولة';
      default:
        return 'لم يبدأ بعد';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Color(0xFF2F6F5E),
      ),
    );
  }
}

class _GoogleAccountRow extends StatelessWidget {
  const _GoogleAccountRow({
    required this.account,
    required this.onSignIn,
    required this.onSignOut,
  });

  final GoogleSignInAccount? account;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F6F5E).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle_rounded,
              size: 28, color: Color(0xFF2F6F5E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              account?.email ?? 'لم يتم تسجيل الدخول بحساب Google',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: account == null ? onSignIn : onSignOut,
            child: Text(account == null ? 'تسجيل الدخول' : 'خروج'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.title,
    required this.icon,
    required this.rows,
    required this.actions,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;
  final List<Widget> actions;
  final Widget? trailing;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      r.value,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...actions,
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2F6F5E),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2F6F5E),
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: const BorderSide(
            color: Color(0xFF2F6F5E),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
