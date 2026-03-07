import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/errors/app_exception.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';

class OrderWorkflowEngine {
  const OrderWorkflowEngine();

  static const Map<OrderStatus, OrderStatus?> _nextState = {
    OrderStatus.entered: OrderStatus.checked,
    OrderStatus.checked: OrderStatus.approved,
    OrderStatus.approved: OrderStatus.shipped,
    OrderStatus.shipped: OrderStatus.completed,
    OrderStatus.completed: OrderStatus.returned,
    OrderStatus.returned: null,
  };

  void ensureCanCreate(AppUser actor) {
    if (actor.hasPermission(AppPermission.ordersCreate)) {
      return;
    }
    throw AppException('Missing permission orders_create.');
  }

  void ensureCanTransition({
    required AppUser actor,
    required OrderStatus current,
    required OrderStatus next,
  }) {
    final expected = _nextState[current];
    if (expected != next) {
      throw AppException('Invalid state transition: ${current.name} -> ${next.name}.');
    }

    if (!_canMoveTo(actor, next)) {
      throw AppException('You do not have permission to move an order to ${next.name}.');
    }
  }

  List<OrderStatus> availableTransitions({
    required AppUser actor,
    required OrderStatus current,
  }) {
    final next = _nextState[current];
    if (next == null) {
      return const [];
    }

    return _canMoveTo(actor, next) ? [next] : const [];
  }

  List<UserRole> notificationTargetsForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.entered:
      case OrderStatus.checked:
      case OrderStatus.approved:
        return const [UserRole.reviewer, UserRole.admin];
      case OrderStatus.shipped:
      case OrderStatus.completed:
        return const [UserRole.shipping, UserRole.admin];
      case OrderStatus.returned:
        return const [UserRole.admin];
    }
  }

  bool _canMoveTo(AppUser actor, OrderStatus next) {
    if (actor.hasPermission(AppPermission.ordersOverride)) {
      return true;
    }

    switch (next) {
      case OrderStatus.checked:
      case OrderStatus.approved:
        return actor.hasPermission(AppPermission.ordersApprove);
      case OrderStatus.shipped:
      case OrderStatus.completed:
      case OrderStatus.returned:
        return actor.hasPermission(AppPermission.ordersShip);
      case OrderStatus.entered:
        return actor.hasPermission(AppPermission.ordersCreate);
    }
  }
}
