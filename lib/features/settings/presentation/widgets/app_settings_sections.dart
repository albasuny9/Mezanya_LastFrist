import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';

class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({
    super.key,
    required this.nameController,
    required this.onNameChanged,
    required this.googleLabel,
    required this.onGoogleSignIn,
  });

  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final String googleLabel;
  final VoidCallback onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اسم المستخدم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              onChanged: onNameChanged,
              decoration: const InputDecoration(hintText: 'اكتب اسمك'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onGoogleSignIn,
              icon: const Icon(Icons.login),
              label: Text(googleLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class CurrencySettingsCard extends StatelessWidget {
  const CurrencySettingsCard({
    super.key,
    required this.currency,
    required this.onChanged,
  });

  final String currency;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'العملة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: currency,
              items: [
                DropdownMenuItem(value: 'EGP', child: Text('جنيه مصري (EGP)')),
                DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                DropdownMenuItem(
                    value: 'USD', child: Text('دولار أمريكي (USD)')),
                DropdownMenuItem(value: 'EUR', child: Text('يورو (EUR)')),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsSettingsTile extends StatelessWidget {
  const NotificationsSettingsTile({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('الإشعارات'),
        subtitle: Text(enabled ? 'مفعلة' : 'موقوفة'),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

class BackupManagementCard extends StatelessWidget {
  const BackupManagementCard({
    super.key,
    required this.backupDir,
    required this.autoBackupMode,
    required this.onBackupLocal,
    required this.onPickBackupDirectory,
    required this.onAutoBackupModeChanged,
    required this.onRestoreLocal,
    required this.onBackupDrive,
    required this.onRestoreDrive,
  });

  final String backupDir;
  final String autoBackupMode;
  final VoidCallback onBackupLocal;
  final VoidCallback onPickBackupDirectory;
  final ValueChanged<String?> onAutoBackupModeChanged;
  final VoidCallback onRestoreLocal;
  final VoidCallback onBackupDrive;
  final VoidCallback onRestoreDrive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إدارة النسخ الاحتياطي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onBackupLocal,
              icon: const Icon(Icons.download),
              label: const Text('حفظ نسخة محلية الآن (اختيار المكان)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPickBackupDirectory,
              icon: const Icon(Icons.folder_open),
              label: backupDir.isEmpty
                  ? const Text('اختيار مكان حفظ النسخ المحلية')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مكان الحفظ'),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            backupDir,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: autoBackupMode,
              decoration: const InputDecoration(
                labelText: 'النسخ الاحتياطي التلقائي',
              ),
              items: [
                DropdownMenuItem(value: 'off', child: Text('إيقاف')),
                DropdownMenuItem(
                    value: RecurrencePattern.daily.value, child: Text('يومي')),
                DropdownMenuItem(
                    value: RecurrencePattern.weekly.value,
                    child: Text('أسبوعي')),
                DropdownMenuItem(
                  value: 'on-close',
                  child: Text('عند إغلاق التطبيق'),
                ),
              ],
              onChanged: onAutoBackupModeChanged,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRestoreLocal,
              icon: const Icon(Icons.upload_file),
              label: const Text('استرجاع يدوي من ملف JSON'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onBackupDrive,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('رفع النسخة إلى Google Drive'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRestoreDrive,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('استرجاع من Google Drive'),
            ),
            const SizedBox(height: 8),
            const Text(
              'مهم: الاسترجاع المحلي يتم يدويًا باختيار ملف JSON من مدير الملفات (مناسب بعد إعادة تثبيت التطبيق).',
            ),
          ],
        ),
      ),
    );
  }
}

class DangerZoneCard extends StatelessWidget {
  const DangerZoneCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Card(
      child: ListTile(
        leading: Icon(Icons.delete_forever, color: errorColor),
        title: Text(
          'حذف كل البيانات',
          style: TextStyle(color: errorColor),
        ),
        subtitle: const Text('يتطلب تأكيد قبل الحذف'),
        onTap: onTap,
      ),
    );
  }
}

class AppInfoCard extends StatelessWidget {
  const AppInfoCard({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('الميزانية'),
        subtitle: Text('المستخدم: ${userName.isEmpty ? 'غير محدد' : userName}'),
        trailing: const Text('v1.0.0'),
      ),
    );
  }
}
