import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_state/data/repositories/shared_prefs_app_repository.dart';
import '../../features/app_state/data/store/shared_prefs_store.dart';
import '../../features/app_state/domain/repositories/app_repository.dart';
import '../../features/app_state/presentation/cubits/app_cubit.dart';

class AppBootstrap {
  static Future<AppCubit> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsStore(prefs);
    final AppRepository repository = SharedPrefsAppRepository(store);
    final cubit = AppCubit(repository);
    await cubit.initialize();
    return cubit;
  }
}
