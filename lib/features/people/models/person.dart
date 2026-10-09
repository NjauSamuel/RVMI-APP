class Person {
  const Person({
    required this.id,
    required this.name,
    required this.tagId,
    required this.indexedInRekognition,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as int,
    name: json['name'] as String,
    tagId: json['tag_id'] as int? ?? (json['tag'] is Map ? (json['tag'] as Map)['id'] as int? : null),
    indexedInRekognition: json['indexed_in_rekognition'] as bool? ?? false,
  );

  final int id;
  final String name;
  final int? tagId;
  final bool indexedInRekognition;
}
