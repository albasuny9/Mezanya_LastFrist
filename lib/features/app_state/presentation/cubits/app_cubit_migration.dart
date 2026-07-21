part of 'app_cubit.dart';

// جميع منطق الترحيل (migration) الفعلي انتقل إلى AppCubitBase لأنه مستخدم
// من initialize() (الموجودة في AppCubitBase) ومن mixins أخرى (jars, backup).
// تُركت هذه الميكسن فارغة عمداً كأقل تعديل ممكن على تركيب الفصل الحالي.
mixin AppCubitMigrationMixin on AppCubitBase {}
