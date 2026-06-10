import '../entities/app_state_entity.dart';

abstract class AppRepository {
  Future<AppStateEntity> loadState();
  Future<void> saveState(AppStateEntity state);
}
