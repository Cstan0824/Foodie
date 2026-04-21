class CuisineModel {
  final String id;
  final String description;
  final bool isPrimaryOption;

  const CuisineModel({
    required this.id,
    required this.description,
    this.isPrimaryOption = false,
  });

  factory CuisineModel.fromJson(Map<String, dynamic> json) {
    return CuisineModel(
      id: json['type_id'] as String,
      description: json['desc'] as String,
      isPrimaryOption: json['isPrimaryOption'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type_id': id,
      'desc': description,
      'isPrimaryOption': isPrimaryOption,
    };
  }
}
