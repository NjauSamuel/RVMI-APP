class Tag {
  const Tag({required this.id, required this.name, required this.kind, this.reason});

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'moment',
    reason: json['reason'] as String?,
  );

  final int id;
  final String name;
  final String kind;

  /// Set only on `/me/suggested` results: 'favorite' or 'frequently_viewed'.
  final String? reason;

  bool get isPerson => kind == 'person';
}
