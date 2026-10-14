/// Represents a pending synchronization action for offline usage.
class SyncOperation {
  final String id;
  final String type; // 'sync_items', 'update_budget', 'create_month', 'rename_month', 'delete_month'
  final String month;
  final Map<String, dynamic> payload;

  SyncOperation({
    required this.id,
    required this.type,
    required this.month,
    required this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'month': month,
      'payload': payload,
    };
  }

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      month: map['month'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
    );
  }
}
