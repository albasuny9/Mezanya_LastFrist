import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../../features/backup/backup_service.dart';
import '../../../../features/backup/backup_conflict_dialog.dart';

class BackupSettingsScreen extends StatefulWidget {
  final AppCubit cubit;

  const BackupSettingsScreen({
    super.key,
    required this.cubit,
  });

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

enum BackupFrequency {
  onExit,
  daily,
  weekly,
  monthly,
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with WidgetsBindingObserver {
  static const Color _green = Color(0xFF2F6F5E);
  static const Color _bg = Color(0xFFFFFBF1);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  GoogleSignInAccount? _account;
  bool loading = false;
  String? localPath;
  String? _lastBackupAt;
  BackupFrequency localFreq = BackupFrequency.onExit;
  BackupFrequency cloudFreq = BackupFrequency.weekly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (localFreq == BackupFrequency.onExit && localPath != null) {
        _saveLocal(silent: true);
      }
      if (cloudFreq == BackupFrequency.onExit && _account != null) {
        _backupFirestoreSilent();
      }
    }
  }

  Future<void> _loadGoogle() async {
    _account = _googleSignIn.currentUser;
    _account ??= await _googleSignIn.signInSilently();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    localPath = prefs.getString('backup_local_path');
    _lastBackupAt = prefs.getString('last_cloud_backup_at');
    final local = prefs.getString('backup_local_freq');
    final cloud = prefs.getString('backup_cloud_freq');
    if (local != null) {
      localFreq = BackupFrequency.values.firstWhere(
        (e) => e.name == local,
        orElse: () => BackupFrequency.onExit,
      );
    }
    if (cloud != null) {
      cloudFreq = BackupFrequency.values.firstWhere(
        (e) => e.name == cloud,
        orElse: () => BackupFrequency.weekly,
      );
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_local_path', localPath ?? '');
    await prefs.setString('backup_local_freq', localFreq.name);
    await prefs.setString('backup_cloud_freq', cloudFreq.name);
  }

  bool _guardAuth() {
    if (_account == null) {
      _msg('سجل دخول بجوجل أولًا');
      return false;
    }
    return true;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _freqLabel(BackupFrequency f) {
    switch (f) {
      case BackupFrequency.onExit:
        return 'مع غلق التطبيق';
      case BackupFrequency.daily:
        return 'يوميًا 12 صباحًا';
      case BackupFrequency.weekly:
        return 'كل جمعة 12 صباحًا';
      case BackupFrequency.monthly:
        return '1 من كل شهر';
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<void> _pickFolder() async {
    final ok = await _requestStoragePermission();
    if (!ok) return;
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    setState(() => localPath = path);
    await _savePrefs();
    _msg('تم حفظ مجلد النسخ');
  }

  Future<void> _saveLocal({bool silent = false}) async {
    if (localPath == null) {
      // لا يوجد مجلد — اطلب الصلاحية واختر مجلداً أولاً
      final ok = await _requestStoragePermission();
      if (!ok) return;
      final picked = await FilePicker.getDirectoryPath();
      if (picked == null) return;
      setState(() => localPath = picked);
      await _savePrefs();
    }
    try {
      final path = '$localPath${Platform.pathSeparator}mezanya_backup.json';
      final file = File(path);
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(widget.cubit.exportStateJson(), flush: true);
      if (!silent) _msg('تم حفظ النسخة محليًا ✓');
    } catch (_) {
      if (!silent) _msg('فشل حفظ النسخة');
    }
  }

  Future<void> _restoreLocal() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final json = await File(result.files.single.path!).readAsString();
    await widget.cubit.importStateJson(json);
    _msg('تم الاسترجاع المحلي');
  }

  Future<void> _backupFirestore() async {
    if (!_guardAuth()) return;

    final appState = widget.cubit.state;

    // لا نرفع نسخة فارغة أبداً
    if (appState.isEmpty) {
      _msg('لا توجد بيانات للرفع بعد');
      return;
    }

    try {
      setState(() => loading = true);

      final email = _account!.email;
      final existingMeta = await BackupService.fetchMetadata(email);

      if (existingMeta != null) {
        // يوجد نسخة قديمة — نسأل المستخدم
        if (!mounted) return;
        final remoteTx =
            (existingMeta['recordsCount']?['transactions'] as int?) ?? 0;
        final remoteUpdatedAt = existingMeta['updatedAt'] is Timestamp
            ? (existingMeta['updatedAt'] as Timestamp).toDate()
            : null;

        final choice = await BackupConflictDialog.show(
          context,
          remoteTxCount: remoteTx,
          localTxCount: appState.transactions.length,
          remoteUpdatedAt: remoteUpdatedAt,
        );

        if (choice == BackupConflictChoice.cancel) return;

        if (choice == BackupConflictChoice.merge) {
          // نجلب البيانات الكاملة ونعمل merge
          final remoteJson = await BackupService.fetchData(email);
          if (remoteJson != null) {
            await widget.cubit.mergeStateJson(remoteJson);
          }
        }
        // في حالة overwrite أو بعد merge — نرفع الحالة الحالية
      }

      final currentState = widget.cubit.state;
      await BackupService.upload(
        email: email,
        displayName: _account!.displayName ?? '',
        jsonData: widget.cubit.exportStateJson(),
        txCount: currentState.transactions.length,
        walletCount: currentState.wallets.length,
        recurringCount: currentState.recurringTransactions.length,
      );

      // نحفظ وقت آخر رفع محلياً
      final now = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_cloud_backup_at', now);
      if (mounted) setState(() => _lastBackupAt = now);

      _msg('تم رفع النسخة بنجاح ✓');
    } catch (e) {
      _msg('فشل رفع النسخة');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// رفع صامت عند غلق التطبيق — لا يُظهر dialogs أو loading.
  Future<void> _backupFirestoreSilent() async {
    if (_account == null) return;
    final appState = widget.cubit.state;
    if (appState.isEmpty) return;
    try {
      await BackupService.upload(
        email: _account!.email,
        displayName: _account!.displayName ?? '',
        jsonData: widget.cubit.exportStateJson(),
        txCount: appState.transactions.length,
        walletCount: appState.wallets.length,
        recurringCount: appState.recurringTransactions.length,
      );
      final now = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_cloud_backup_at', now);
    } catch (_) {
      // صامت — لا نُظهر أي خطأ
    }
  }

  Future<void> _restoreFirestore() async {
    if (!_guardAuth()) return;
    try {
      setState(() => loading = true);
      final json = await BackupService.fetchData(_account!.email);
      if (json == null) {
        _msg('لا توجد نسخة محفوظة');
        return;
      }
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع بنجاح ✓');
    } catch (_) {
      _msg('فشل الاسترجاع');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: const Color(0xFF1C3A32),
        title: const Text(
          'النسخة الاحتياطية',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // ── النسخ المحلي (أولاً) ────────────────────────────────
              _sectionHeader('النسخ المحلي', Icons.phone_android_rounded),
              _BackupCard(
                children: [
                  // مكان الحفظ
                  _pathTile(
                    icon: Icons.folder_rounded,
                    label: 'مكان الحفظ',
                    value: localPath ?? 'لم يتم الاختيار بعد',
                    onTap: _pickFolder,
                  ),
                  const SizedBox(height: 14),
                  // تكرار النسخ
                  _FrequencySelector(
                    label: 'تكرار النسخ المحلي',
                    value: localFreq,
                    options: BackupFrequency.values,
                    labelOf: _freqLabel,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => localFreq = v);
                      _savePrefs();
                    },
                  ),
                  if (localFreq == BackupFrequency.onExit) ...[
                    const SizedBox(height: 10),
                    _InfoBanner(
                      text:
                          'سيتم تحديث النسخة تلقائياً عند الضغط على رجوع أو غلق التطبيق.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: 'إنشاء نسخة الآن',
                    icon: Icons.save_rounded,
                    onTap: () => _saveLocal(),
                  ),
                  const SizedBox(height: 8),
                  _SecondaryButton(
                    label: 'استرجاع نسخة محلية',
                    icon: Icons.restore_rounded,
                    onTap: _restoreLocal,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── النسخ السحابي ─────────────────────────────────────
              _sectionHeader('النسخ السحابي', Icons.cloud_rounded),
              _CloudBackupCard(
                account: _account,
                lastBackupLabel: _formatBackupTime(_lastBackupAt),
                txCount: widget.cubit.state.transactions.length,
                isLoading: loading,
                cloudFreq: cloudFreq,
                freqLabel: _freqLabel,
                onFreqChanged: (v) {
                  if (v == null) return;
                  setState(() => cloudFreq = v);
                  _savePrefs();
                },
                onUpload: _backupFirestore,
                onRestore: _restoreFirestore,
              ),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _green),
                      SizedBox(height: 14),
                      Text(
                        'جارٍ التحميل...',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: _green),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C3A32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1C3A32),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _green.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                color: _green.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: _green.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _green.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudBackupCard extends StatelessWidget {
  const _CloudBackupCard({
    required this.account,
    required this.lastBackupLabel,
    required this.txCount,
    required this.isLoading,
    required this.cloudFreq,
    required this.freqLabel,
    required this.onFreqChanged,
    required this.onUpload,
    required this.onRestore,
  });

  final dynamic account; // GoogleSignInAccount?
  final String lastBackupLabel;
  final int txCount;
  final bool isLoading;
  final BackupFrequency cloudFreq;
  final String Function(BackupFrequency) freqLabel;
  final ValueChanged<BackupFrequency?> onFreqChanged;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  static const _green = Color(0xFF2F6F5E);
  static const _orange = Color(0xFFC65D2E);

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = account != null;
    final hasBackup = lastBackupLabel != 'لم يتم النسخ بعد';
    final statusColor =
        isLoggedIn ? (hasBackup ? _green : _orange) : const Color(0xFF888888);

    return _BackupCard(
      children: [
        // ── بادج الحساب + حالة النسخ في كارت واحد ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // أيقونة G
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.07),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoggedIn
                          ? const Text('G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Arial',
                                color: Color(0xFF4285F4),
                              ))
                          : Icon(Icons.cloud_off_rounded,
                              size: 20, color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoggedIn ? 'متصل بجوجل' : 'غير مرتبط بحساب جوجل',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoggedIn
                              ? (account!.email as String? ?? '')
                              : 'سجل دخول من إعدادات الحساب',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // مؤشر الاتصال
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          isLoggedIn ? 'متصل' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isLoggedIn) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      hasBackup
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      size: 16,
                      color: statusColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasBackup
                            ? 'آخر نسخة: $lastBackupLabel · $txCount معاملة'
                            : 'لم يتم رفع أي نسخة بعد',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    // زر رفع سريع
                    isLoading
                        ? SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: _green,
                            ),
                          )
                        : GestureDetector(
                            onTap: onUpload,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.cloud_upload_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── تكرار النسخ ──
        _FrequencySelector(
          label: 'تكرار النسخ السحابي',
          value: cloudFreq,
          options: BackupFrequency.values,
          labelOf: freqLabel,
          onChanged: onFreqChanged,
        ),
        if (cloudFreq == BackupFrequency.onExit) ...[
          const SizedBox(height: 10),
          _InfoBanner(
            text:
                'سيتم رفع النسخة السحابية تلقائياً عند الضغط على رجوع أو غلق التطبيق.',
          ),
        ],
        const SizedBox(height: 16),
        _PrimaryButton(
          label: 'رفع نسخة الآن',
          icon: Icons.cloud_upload_rounded,
          onTap: isLoggedIn ? onUpload : () {},
        ),
        const SizedBox(height: 8),
        _SecondaryButton(
          label: 'استرجاع من السحابة',
          icon: Icons.cloud_download_rounded,
          onTap: isLoggedIn ? onRestore : () {},
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF2F6F5E).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 5),
            color: const Color(0xFF2F6F5E).withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FrequencySelector<T> extends StatelessWidget {
  const _FrequencySelector({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _green.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withValues(alpha: 0.18)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.expand_more_rounded,
                  color: _green.withValues(alpha: 0.7)),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C3A32),
              ),
              items: options
                  .map((e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(labelOf(e)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
