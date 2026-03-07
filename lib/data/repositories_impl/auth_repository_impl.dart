import 'package:warehouse_manager_app/data/datasources/remote/backend_data_source.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final BackendDataSource _dataSource;

  @override
  Future<AppUser?> getCurrentUser() => _dataSource.getCurrentUser();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _dataSource.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Stream<AppUser?> watchSession() => _dataSource.watchSession();
}
