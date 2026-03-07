import 'package:warehouse_manager_app/core/services/order_workflow_engine.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/repositories/wms_repository.dart';

class CreateOrderUseCase {
  const CreateOrderUseCase(this._repository, this._workflow);

  final WmsRepository _repository;
  final OrderWorkflowEngine _workflow;

  Future<void> call({
    required AppUser actor,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) {
    _workflow.ensureCanCreate(actor);
    return _repository.createOrder(
      actor: actor,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      items: items,
    );
  }
}
