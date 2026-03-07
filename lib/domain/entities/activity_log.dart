class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.entityId,
    this.metadata,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String entityType;
  final String? entityId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
}
