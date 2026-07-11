// ignore_for_file: use_build_context_synchronously
import 'dart:developer';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/backup/backup_service.dart';
import 'package:mezanya_app/features/backup/restore_prompt_dialog.dart';
import 'backup_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.cubit,
  });

  final AppCubit cubit;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late TextEditingController _nameController;
  String _selectedLanguage = 'ar';

  static const _bg = Color(0xFFFFFBF1);
  static const _green = Color(0xFF2F6F5E);
  static const _surface = Color(0xFFFFFFFF);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  GoogleSignInAccount? _account;

  bool _uploadingImage = false;

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
    _nameController = TextEditingController(
      text: widget.cubit.state.userName,
    );
    _initGoogle();
  }

  Future<void> _initGoogle() async {
    final cached = _googleSignIn.currentUser;
    if (cached != null) {
      await _signInFirebaseWithGoogle(cached);
      _account = cached;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = cached.displayName ?? '';
      }
      if (mounted) setState(() {});
      return;
    }
    final acc = await _googleSignIn.signInSilently();
    if (!mounted) return;
    if (acc != null) {
      await _signInFirebaseWithGoogle(acc);
      _account = acc;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = acc.displayName ?? '';
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfileImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final Uint8List bytes = result.files.single.bytes!;
    final ext = result.files.single.extension ?? 'jpg';
    setState(() => _uploadingImage = true);
    try {
      final uid =
          _account?.id ?? widget.cubit.state.userName.hashCode.toString();
      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$uid.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      await widget.cubit.updateSettings(profileImageUrl: url);
    } catch (e) {
      log('Image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snap) {
        final state = snap.data ?? widget.cubit.state;
        final displayName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (_account?.displayName ?? 'مستخدم');
        final initials = displayName.isNotEmpty ? displayName[0] : 'م';
        final isGoogleConnected = _account != null;

        return Scaffold(
          backgroundColor: _bg,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              const SizedBox(height: 8),
              _ProfileCard(
                profileImageUrl: state.profileImageUrl,
                googlePhotoUrl: _account?.photoUrl,
                initials: initials,
                nameController: _nameController,
                isGoogleConnected: isGoogleConnected,
                googleAccount: _account,
                uploadingImage: _uploadingImage,
                onPickImage: _pickAndUploadProfileImage,
                onNameChanged: (v) => widget.cubit.updateSettings(userName: v),
              ),

              const SizedBox(height: 20),

              _SectionHeader(
                label: 'إعداد اللغة والعملة',
                icon: Icons.language_rounded,
              ),
              _LanguageCurrencyCard(
                currencyCode: state.currencyCode,
                selectedLanguage: _selectedLanguage,
                onCurrencyChanged: (value) {
                  if (value == null || value == state.currencyCode) return;
                  widget.cubit.updateSettings(currencyCode: value);
                },
                onLanguageChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedLanguage = value);
                },
              ),

              const SizedBox(height: 20),

              // ── ربط الحساب ────────────────────────────────────
              _SectionHeader(label: 'ربط الحساب', icon: Icons.link_rounded),
              _AccountLinkCard(
                googleAccount: _account,
                onGoogleSignIn: _signInGoogle,
                onGoogleSignOut: _signOutGoogle,
              ),

              const SizedBox(height: 20),

              // ── البيانات ──────────────────────────────────────
              _SectionHeader(label: 'البيانات', icon: Icons.storage_rounded),
              _ActionTile(
                icon: Icons.backup_rounded,
                iconColor: _green,
                title: 'إدارة النسخ الاحتياطي',
                subtitle: 'نسخ محلي و Firebase',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupSettingsScreen(cubit: widget.cubit),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.delete_sweep_rounded,
                iconColor: const Color(0xFFC65D2E),
                iconBgColor: const Color(0xFFC65D2E).withValues(alpha: 0.1),
                title: 'مسح بيانات التطبيق',
                subtitle: 'إعادة ضبط كاملة لجميع البيانات',
                titleColor: const Color(0xFFC65D2E),
                onTap: _showWipeSheet,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signInGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      await _signInFirebaseWithGoogle(account);
      _nameController.text = account.displayName ?? '';
      widget.cubit.updateSettings(
        userName: _nameController.text,
        googleEmail: account.email,
      );
      setState(() => _account = account);

      // بعد تسجيل الدخول — نتحقق من وجود نسخة على السحابة
      await _checkAndPromptRestore(account.email);
    } catch (e) {
      log('$e');
    }
  }

  Future<void> _checkAndPromptRestore(String email) async {
    try {
      // نتحقق إذا سبق وسألنا المستخدم لهذا الحساب
      final prefs = await SharedPreferences.getInstance();
      final promptKey = 'restore_prompt_shown_$email';
      final alreadyShown = prefs.getBool(promptKey) ?? false;
      if (alreadyShown) return;

      // البيانات المحلية فارغة؟
      if (!widget.cubit.state.isEmpty) {
        await prefs.setBool(promptKey, true);
        return;
      }

      // ترتيب البحث الإلزامي عن أي نسخة متاحة: يدوي سحابي أولاً، ثم
      // تلقائي سحابي، ثم النسخة القديمة (Legacy) كملاذ أخير. أول نسخة
      // توجد هي التي تُعرَض للمستخدم.
      BackupSlot? foundSlot;
      Map<String, dynamic>? meta = await BackupService.fetchSlotMetadata(
        email,
        BackupSlot.manualCloud,
      );
      if (meta != null) {
        foundSlot = BackupSlot.manualCloud;
      } else {
        final latestAuto = await BackupService.latestAutoSlot(email);
        if (latestAuto != null) {
          meta = await BackupService.fetchSlotMetadata(email, latestAuto);
          foundSlot = latestAuto;
        }
      }
      final isLegacy = meta == null;
      meta ??= await BackupService.fetchLegacyMetadata(email);

      if (meta == null) {
        await prefs.setBool(promptKey, true);
        return;
      }

      final txCount = (meta['recordsCount']?['transactions'] as int?) ?? 0;
      final walletCount = (meta['recordsCount']?['wallets'] as int?) ?? 0;
      final updatedAt = meta['updatedAt'] is Timestamp
          ? (meta['updatedAt'] as Timestamp).toDate()
          : null;

      if (!mounted) return;

      final restore = await RestorePromptDialog.show(
        context,
        txCount: txCount,
        walletCount: walletCount,
        updatedAt: updatedAt,
      );

      await prefs.setBool(promptKey, true);

      if (restore) {
        // لا نُهاجر النسخة القديمة تلقائيًا — نقرأها فقط للاسترجاع، وتبقى
        // كما هي على مسارها القديم (Legacy) بلا أي كتابة.
        final json = isLegacy
            ? await BackupService.fetchLegacyData(email)
            : await BackupService.fetchSlotData(email, foundSlot!);
        if (json != null) {
          await widget.cubit.importStateJson(json);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم استعادة بياناتك بنجاح ✓')),
            );
          }
        }
      }
    } catch (e) {
      log('restore check error: $e');
    }
  }

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    widget.cubit.updateSettings(googleEmail: '');
    setState(() => _account = null);
  }

  Future<void> _showWipeSheet() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        int count = 5;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future.doWhile(() async {
              if (count == 0) return false;
              await Future.delayed(const Duration(seconds: 1));
              count--;
              if (ctx.mounted) setSheet(() {});
              return count > 0;
            });

            return Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC65D2E).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 36, color: Color(0xFFC65D2E)),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تحذير الأمان',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'أنت على وشك البدء في عملية حذف البيانات.\nيرجى الانتظار للمتابعة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: count > 0 ? null : () => _showSelectionSheet(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC65D2E),
                        disabledBackgroundColor:
                            const Color(0xFFC65D2E).withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        count > 0 ? 'انتظر $count ثواني...' : 'متابعة الخيارات',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSelectionSheet() async {
    Navigator.pop(context); // Close countdown 1
    final selected = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool tx = true;
        bool logs = true;
        bool wallets = true;
        bool recurring = true;
        bool budget = true;
        bool cats = true;
        bool goals = true;
        bool notifs = true;

        return StatefulBuilder(
          builder: (stCtx, setSt) {
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تحديد البيانات المراد حذفها',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  _wipeOption(
                      'المعاملات المالية', tx, (v) => setSt(() => tx = v!)),
                  _wipeOption(
                      'سجل النشاط (Logs)', logs, (v) => setSt(() => logs = v!)),
                  _wipeOption('المحافظ والأرصدة', wallets,
                      (v) => setSt(() => wallets = v!)),
                  _wipeOption('المعاملات المتكررة (ديون واشتراكات)', recurring,
                      (v) => setSt(() => recurring = v!)),
                  _wipeOption('خطة الميزانية والدخل', budget,
                      (v) => setSt(() => budget = v!)),
                  _wipeOption(
                      'الفئات المخصصة', cats, (v) => setSt(() => cats = v!)),
                  _wipeOption(
                      'أهداف التوفير', goals, (v) => setSt(() => goals = v!)),
                  _wipeOption('تاريخ الإشعارات', notifs,
                      (v) => setSt(() => notifs = v!)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(stCtx, {
                        'tx': tx,
                        'logs': logs,
                        'wallets': wallets,
                        'recurring': recurring,
                        'budget': budget,
                        'cats': cats,
                        'goals': goals,
                        'notifs': notifs,
                      }),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC65D2E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('تأكيد الاختيارات',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(stCtx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;
    _finalDeleteCountdown(selected);
  }

  Widget _wipeOption(String label, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFC65D2E),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Future<void> _finalDeleteCountdown(Map<String, bool> selected) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        int count = 5;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future.doWhile(() async {
              if (count == 0) return false;
              await Future.delayed(const Duration(seconds: 1));
              count--;
              if (ctx.mounted) setSheet(() {});
              return count > 0;
            });

            return Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تأكيد نهائي',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC65D2E)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'هل أنت متأكد تماماً؟ سيتم حذف البيانات المختارة نهائياً ولا يمكن الرجوع عنها.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: count > 0
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await widget.cubit.wipeDataSelective(
                                transactions: selected['tx'] ?? false,
                                logs: selected['logs'] ?? false,
                                wallets: selected['wallets'] ?? false,
                                recurring: selected['recurring'] ?? false,
                                budget: selected['budget'] ?? false,
                                categories: selected['cats'] ?? false,
                                goals: selected['goals'] ?? false,
                                notifications: selected['notifs'] ?? false,
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('تم حذف البيانات المختارة بنجاح')),
                              );
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC65D2E),
                        disabledBackgroundColor:
                            const Color(0xFFC65D2E).withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        count > 0
                            ? 'تأكيد الحذف النهائي ($count)...'
                            : 'حذف الآن',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profileImageUrl,
    required this.googlePhotoUrl,
    required this.initials,
    required this.nameController,
    required this.isGoogleConnected,
    required this.googleAccount,
    required this.uploadingImage,
    required this.onPickImage,
    required this.onNameChanged,
  });

  final String profileImageUrl;
  final String? googlePhotoUrl;
  final String initials;
  final TextEditingController nameController;
  final bool isGoogleConnected;
  final GoogleSignInAccount? googleAccount;
  final bool uploadingImage;
  final VoidCallback onPickImage;
  final ValueChanged<String> onNameChanged;

  static const _green = Color(0xFF2F6F5E);

  String? get _effectivePhoto =>
      profileImageUrl.isNotEmpty ? profileImageUrl : googlePhotoUrl;

  String get _connectedEmail => googleAccount?.email ?? '';

  bool get _anyConnected => isGoogleConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2F6F5E).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: const Color(0xFF2F6F5E).withValues(alpha: 0.07),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Avatar header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF2F6F5E), Color(0xFF1A4A3A)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: uploadingImage
                          ? const CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              backgroundImage: _effectivePhoto != null
                                  ? NetworkImage(_effectivePhoto!)
                                  : null,
                              child: _effectivePhoto == null
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : null,
                            ),
                    ),
                    // Camera button overlay
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onPickImage,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _green.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 6,
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                    if (_anyConnected)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_anyConnected && _connectedEmail.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          _connectedEmail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'غير متصل بأي حساب',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على أيقونة الكاميرا لتغيير الصورة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ─── Name field
          Padding(
            padding: const EdgeInsets.all(18),
            child: TextField(
              controller: nameController,
              onChanged: onNameChanged,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                labelStyle: TextStyle(
                  color: _green.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon:
                    const Icon(Icons.person_outline_rounded, color: _green),
                filled: true,
                fillColor: const Color(0xFFF5FAF8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _green.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Link Card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountLinkCard extends StatelessWidget {
  const _AccountLinkCard({
    required this.googleAccount,
    required this.onGoogleSignIn,
    required this.onGoogleSignOut,
  });

  final GoogleSignInAccount? googleAccount;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGoogleSignOut;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    final isConnected = googleAccount != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _green.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: _green.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with context
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: _GoogleIcon(size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مزامنة السحابية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A4A3A),
                        ),
                      ),
                      Text(
                        'احفظ بياناتك واسترجعها في أي وقت',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 12, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text(
                          'متصل',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (isConnected) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: googleAccount!.photoUrl != null
                            ? NetworkImage(googleAccount!.photoUrl!)
                            : null,
                        child: googleAccount!.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              googleAccount!.displayName ?? 'مستخدم جوجل',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              googleAccount!.email,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onGoogleSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('تبديل الحساب أو الخروج'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC65D2E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'اربط حسابك بجوجل لتفعيل النسخ الاحتياطي التلقائي والمزامنة بين أجهزتك المختلفة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onGoogleSignIn,
                      icon: _GoogleIcon(size: 18, color: Colors.white),
                      label: const Text('تسجيل الدخول باستخدام Google'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A4A3A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCurrencyCard extends StatelessWidget {
  const _LanguageCurrencyCard({
    required this.currencyCode,
    required this.selectedLanguage,
    required this.onCurrencyChanged,
    required this.onLanguageChanged,
  });

  final String currencyCode;
  final String selectedLanguage;
  final ValueChanged<String?> onCurrencyChanged;
  final ValueChanged<String?> onLanguageChanged;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _green.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: _green.withValues(alpha: 0.07),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SettingsDropdownField(
              label: 'العملة',
              icon: Icons.attach_money_rounded,
              value: currencyCode,
              items: const [
                DropdownMenuItem(value: 'EGP', child: Text('جنيه مصري (EGP)')),
                DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                DropdownMenuItem(
                    value: 'USD', child: Text('دولار أمريكي (USD)')),
                DropdownMenuItem(value: 'EUR', child: Text('يورو (EUR)')),
              ],
              onChanged: onCurrencyChanged,
            ),
            const SizedBox(height: 14),
            _SettingsDropdownField(
              label: 'اللغة',
              icon: Icons.translate_rounded,
              value: selectedLanguage,
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: onLanguageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDropdownField extends StatelessWidget {
  const _SettingsDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _green),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _green.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: _green),
        filled: true,
        fillColor: const Color(0xFFF5FAF8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _green.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (color != null) {
      return Icon(Icons.g_mobiledata_rounded, size: size + 10, color: color);
    }
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_Color_Icon.svg/1200px-Google_Color_Icon.svg.png',
      width: size,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.account_circle, size: size, color: Colors.blue),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBgColor,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    final bgColor = iconBgColor ?? _green.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 4),
              color: iconColor.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
