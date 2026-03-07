enum AppMode { setupRequired, live }

enum UserRole {
  orderEntry('Order Entry User'),
  reviewer('Order Reviewer'),
  shipping('Shipping User'),
  admin('Admin');

  const UserRole(this.label);

  final String label;

  static UserRole fromRoleName(String value) {
    switch (value.toLowerCase()) {
      case 'order reviewer':
      case 'reviewer':
        return UserRole.reviewer;
      case 'shipping user':
      case 'shipping':
        return UserRole.shipping;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.orderEntry;
    }
  }
}

enum OrderStatus {
  entered,
  checked,
  approved,
  shipped,
  completed,
  returned;
}

enum NotificationType {
  workflow,
  alert,
  system;
}

enum AppPermission {
  ordersView('orders_view'),
  ordersCreate('orders_create'),
  ordersEdit('orders_edit'),
  ordersDelete('orders_delete'),
  ordersApprove('orders_approve'),
  ordersShip('orders_ship'),
  ordersOverride('orders_override'),
  inventoryView('inventory_view'),
  inventoryEdit('inventory_edit'),
  productsView('products_view'),
  productsCreate('products_create'),
  productsEdit('products_edit'),
  productsDelete('products_delete'),
  reportsView('reports_view'),
  usersView('users_view'),
  usersCreate('users_create'),
  usersEdit('users_edit'),
  usersDelete('users_delete'),
  usersAssignPermissions('users_assign_permissions'),
  dashboardView('dashboard_view'),
  notificationsView('notifications_view'),
  activityLogsView('activity_logs_view');

  const AppPermission(this.code);

  final String code;

  static AppPermission? fromCode(String code) {
    for (final permission in values) {
      if (permission.code == code) {
        return permission;
      }
    }
    return null;
  }
}
