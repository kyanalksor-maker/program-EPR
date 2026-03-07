import 'package:warehouse_manager_app/domain/entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchSession();
  Future<AppUser?> getCurrentUser();
  Future<void> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
}
