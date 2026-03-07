import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/services/order_workflow_engine.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/repositories/wms_repository.dart';

class TransitionOrderUseCase {
  const TransitionOrderUseCase(this._repository, this._workflow);

  final WmsRepository _repository;
  final OrderWorkflowEngine _workflow;

  Future<void> call({
    required AppUser actor,
    required OrderEntity order,
    required OrderStatus nextStatus,
    String? note,
  }) {
    _workflow.ensureCanTransition(
      actor: actor,
      current: order.status,
      next: nextStatus,
    );

    return _repository.transitionOrder(
      actor: actor,
      orderId: order.id,
      nextStatus: nextStatus,
      note: note,
    );
  }
}
