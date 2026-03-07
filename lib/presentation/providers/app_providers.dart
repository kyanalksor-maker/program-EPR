import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/services/order_workflow_engine.dart';
import 'package:warehouse_manager_app/core/services/supabase_bootstrap.dart';
import 'package:warehouse_manager_app/data/datasources/remote/backend_data_source.dart';
import 'package:warehouse_manager_app/data/datasources/remote/supabase_backend_data_source.dart';
import 'package:warehouse_manager_app/data/repositories_impl/auth_repository_impl.dart';
import 'package:warehouse_manager_app/data/repositories_impl/wms_repository_impl.dart';
import 'package:warehouse_manager_app/domain/entities/activity_log.dart';
import 'package:warehouse_manager_app/domain/entities/app_notification.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/dashboard_snapshot.dart';
import 'package:warehouse_manager_app/domain/entities/employee_draft.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';
import 'package:warehouse_manager_app/domain/entities/product_draft.dart';
import 'package:warehouse_manager_app/domain/repositories/auth_repository.dart';
import 'package:warehouse_manager_app/domain/repositories/wms_repository.dart';
import 'package:warehouse_manager_app/domain/usecases/create_order.dart';
import 'package:warehouse_manager_app/domain/usecases/sign_in.dart';
import 'package:warehouse_manager_app/domain/usecases/sign_out.dart';
import 'package:warehouse_manager_app/domain/usecases/transition_order.dart';

final appModeProvider = Provider<AppMode>((ref) => SupabaseBootstrap.mode);

final backendConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(appModeProvider) == AppMode.live,
);

final workflowEngineProvider = Provider<OrderWorkflowEngine>(
  (ref) => const OrderWorkflowEngine(),
);

final backendDataSourceProvider = Provider<BackendDataSource>(
  (ref) => SupabaseBackendDataSource(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(backendDataSourceProvider)),
);

final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => WmsRepositoryImpl(ref.watch(backendDataSourceProvider)),
);

final signInUseCaseProvider = Provider<SignInUseCase>(
  (ref) => SignInUseCase(ref.watch(authRepositoryProvider)),
);

final signOutUseCaseProvider = Provider<SignOutUseCase>(
  (ref) => SignOutUseCase(ref.watch(authRepositoryProvider)),
);

final createOrderUseCaseProvider = Provider<CreateOrderUseCase>(
  (ref) => CreateOrderUseCase(
    ref.watch(wmsRepositoryProvider),
    ref.watch(workflowEngineProvider),
  ),
);

final transitionOrderUseCaseProvider = Provider<TransitionOrderUseCase>(
  (ref) => TransitionOrderUseCase(
    ref.watch(wmsRepositoryProvider),
    ref.watch(workflowEngineProvider),
  ),
);

final sessionProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchSession(),
);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionProvider).valueOrNull,
);

final ordersProvider = StreamProvider<List<OrderEntity>>(
  (ref) => ref.watch(wmsRepositoryProvider).watchOrders(),
);

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(wmsRepositoryProvider).watchProducts(),
);

final usersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(wmsRepositoryProvider).watchUsers(),
);

final activityLogsProvider = StreamProvider<List<ActivityLog>>(
  (ref) => ref.watch(wmsRepositoryProvider).watchActivityLogs(),
);

final dashboardProvider = StreamProvider<DashboardSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watchDashboardSnapshot(),
);

final employeeReportsProvider = StreamProvider<List<EmployeeReport>>(
  (ref) => ref.watch(wmsRepositoryProvider).watchEmployeeReports(),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream<List<AppNotification>>.value(const []);
  }
  return ref.watch(wmsRepositoryProvider).watchNotifications(user.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((notification) => !notification.isRead).length;
});

final hasPermissionProvider = Provider.family<bool, AppPermission>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  return user?.hasPermission(permission) ?? false;
});

final availableTransitionsProvider = Provider.family<List<OrderStatus>, OrderEntity>(
  (ref, order) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const [];
    }
    return ref.watch(workflowEngineProvider).availableTransitions(
      actor: user,
      current: order.status,
    );
  },
);

final orderByIdProvider = Provider.family<OrderEntity?, String>((ref, id) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? const [];
  for (final order in orders) {
    if (order.id == id) {
      return order;
    }
  }
  return null;
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._signIn, this._signOut) : super(const AsyncData(null));

  final SignInUseCase _signIn;
  final SignOutUseCase _signOut;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _signIn(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_signOut.call);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (ref) => AuthController(
    ref.watch(signInUseCaseProvider),
    ref.watch(signOutUseCaseProvider),
  ),
);

class OperationsController extends StateNotifier<AsyncValue<void>> {
  OperationsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  AppUser _requireUser() {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user;
  }

  Future<void> _run(Future<void> Function(AppUser user) action) async {
    final user = _requireUser();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => action(user));
  }

  Future<void> createOrder({
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) {
    return _run(
      (user) => _ref.read(createOrderUseCaseProvider)(
            actor: user,
            customerName: customerName,
            customerPhone: customerPhone,
            notes: notes,
            items: items,
          ),
    );
  }

  Future<void> updateOrder({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).updateOrder(
            actor: user,
            orderId: orderId,
            customerName: customerName,
            customerPhone: customerPhone,
            notes: notes,
            items: items,
          ),
    );
  }

  Future<void> deleteOrder(String orderId) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).deleteOrder(
            actor: user,
            orderId: orderId,
          ),
    );
  }

  Future<void> transitionOrder({
    required OrderEntity order,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _run(
      (user) => _ref.read(transitionOrderUseCaseProvider)(
            actor: user,
            order: order,
            nextStatus: nextStatus,
            note: note,
          ),
    );
  }

  Future<void> overrideOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).overrideOrderStatus(
            actor: user,
            orderId: orderId,
            nextStatus: nextStatus,
            note: note,
          ),
    );
  }

  Future<void> upsertProduct(ProductDraft product) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).upsertProduct(
            actor: user,
            product: product,
          ),
    );
  }

  Future<void> deleteProduct(String productId) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).deleteProduct(
            actor: user,
            productId: productId,
          ),
    );
  }

  Future<void> adjustInventory({
    required String productId,
    required int quantityDelta,
    required String reason,
  }) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).adjustInventory(
            actor: user,
            productId: productId,
            quantityDelta: quantityDelta,
            reason: reason,
          ),
    );
  }

  Future<void> createEmployee(EmployeeDraft employee) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).createEmployee(
            actor: user,
            employee: employee,
          ),
    );
  }

  Future<void> updateEmployee(EmployeeDraft employee) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).updateEmployee(
            actor: user,
            employee: employee,
          ),
    );
  }

  Future<void> deactivateEmployee({
    required String employeeId,
    required bool isActive,
  }) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).deactivateEmployee(
            actor: user,
            employeeId: employeeId,
            isActive: isActive,
          ),
    );
  }

  Future<void> deleteEmployee(String employeeId) {
    return _run(
      (user) => _ref.read(wmsRepositoryProvider).deleteEmployee(
            actor: user,
            employeeId: employeeId,
          ),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _ref.read(wmsRepositoryProvider).markNotificationRead(notificationId),
    );
  }
}

final operationsControllerProvider =
    StateNotifierProvider<OperationsController, AsyncValue<void>>(
  (ref) => OperationsController(ref),
);
