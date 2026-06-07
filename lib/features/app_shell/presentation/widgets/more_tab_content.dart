import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../budget/presentation/screens/budget_setup_screen.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../logs/presentation/screens/logs_screen.dart';
import '../../../notifications/presentation/screens/notifications_center_screen.dart';
import '../../../transactions/presentation/screens/recurring_transactions_screen.dart';
import 'package:mezanya_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'section_page_scaffold.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/presentation/screens/debts_and_subscriptions_screen.dart';

class MoreTabContent extends StatefulWidget {
  final AppCubit cubit;

  const MoreTabContent({
    super.key,
    required this.cubit,
  });

  @override
  State<MoreTabContent> createState() => _MoreTabContentState();
}

class _MoreTabContentState extends State<MoreTabContent> {
  static const _green = Color(0xFF2F6F5E);

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  GoogleSignInAccount? user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final signedUser =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (!mounted) return;
    setState(() => user = signedUser);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;

    final customName = state.userName.trim();
    final googleName = user?.displayName ?? '';
    final name = customName.isNotEmpty
        ? customName
        : (googleName.isNotEmpty ? googleName : 'مستخدم ميزانية');
    final email = user?.email ?? state.googleEmail.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── بطاقة المستخدم ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF2F6F5E), Color(0xFF3C8973)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 6),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white24,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        name[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 15, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email.isEmpty ? 'غير متصل بحساب Google' : email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white),
              ),
            ],
          ),
        ),

        _tile('إعداد الميزانية', Icons.tune_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعداد الميزانية',
                child: BudgetSetupScreen(
                  cubit: widget.cubit,
                  displayMonth: DateTime.now(),
                ),
              ),
            ),
          );
        }),

        _tile('الديون والاشتراكات', Icons.account_balance_wallet_rounded,
            onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtsAndSubscriptionsScreen(cubit: widget.cubit),
            ),
          );
        }),

        _tile('العمليات المتكررة', Icons.repeat_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'العمليات المتكررة',
                child: RecurringTransactionsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('إعداد الفئات', Icons.grid_view_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعداد الفئات',
                child: CategoriesScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('الأهداف', Icons.flag_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'الأهداف',
                child: GoalsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('السجلات', Icons.receipt_long_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LogsScreen(cubit: widget.cubit),
            ),
          );
        }),

        _tile('الإشعارات', Icons.notifications_none, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'الإشعارات',
                child: NotificationsCenterScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('إعدادات التطبيق', Icons.settings_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعدادات التطبيق',
                child: AppSettingsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _tile(String title, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x112F6F5E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _green),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_left),
        ),
      ),
    );
  }
}
