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

class PersonReferencePhoto {
  const PersonReferencePhoto({required this.url, required this.fullUrl});

  factory PersonReferencePhoto.fromJson(Map<String, dynamic> json) => PersonReferencePhoto(
    url: json['url'] as String,
    fullUrl: json['full_url'] as String? ?? json['url'] as String,
  );

  final String url;
  final String fullUrl;
}

class PersonReferences {
  const PersonReferences({required this.id, required this.name, required this.photos});

  factory PersonReferences.fromJson(Map<String, dynamic> json) => PersonReferences(
    id: json['id'] as int,
    name: json['name'] as String,
    photos: (json['photos'] as List? ?? [])
        .map((photo) => PersonReferencePhoto.fromJson(Map<String, dynamic>.from(photo as Map)))
        .toList(),
  );

  final int id;
  final String name;
  final List<PersonReferencePhoto> photos;
}
