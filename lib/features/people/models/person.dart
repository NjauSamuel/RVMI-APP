class Person {
  const Person({
    required this.id,
    required this.name,
    required this.tagId,
    required this.indexedInRekognition,
    required this.referenceFaceCount,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as int,
    name: json['name'] as String,
    tagId: json['tag_id'] as int? ?? (json['tag'] is Map ? (json['tag'] as Map)['id'] as int? : null),
    indexedInRekognition: json['indexed_in_rekognition'] as bool? ?? false,
    referenceFaceCount: (json['reference_face_count'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String name;
  final int? tagId;
  final bool indexedInRekognition;
  final int referenceFaceCount;

  String get referenceLabel {
    if (referenceFaceCount == 1) return '1 reference photo';
    if (referenceFaceCount > 1) return '$referenceFaceCount reference photos';
    if (indexedInRekognition) return 'Trained for auto-recognition';
    return 'No reference photos yet';
  }
}
