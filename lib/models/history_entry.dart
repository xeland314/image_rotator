import 'rotation_operation.dart';

class HistoryEntry {
  final String id;
  final int createdAt; // epoch ms
  final String name;
  final String imageOriginal; // path en disco (no dataURL base64 grande)
  final String imageResult; // path resultado final
  final List<RotationOperation> operations;
  final double totalAngle;
  final double normalizedAngle;
  final String formula;
  final bool showTrace;
  final bool includeDirect;

  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.imageOriginal,
    required this.imageResult,
    required this.operations,
    required this.totalAngle,
    required this.normalizedAngle,
    required this.formula,
    required this.showTrace,
    required this.includeDirect,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt,
        'name': name,
        'imageOriginal': imageOriginal,
        'imageResult': imageResult,
        'operations': operations.map((o) => o.toJson()).toList(),
        'totalAngle': totalAngle,
        'normalizedAngle': normalizedAngle,
        'formula': formula,
        'showTrace': showTrace,
        'includeDirect': includeDirect,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        createdAt: json['createdAt'] as int,
        name: json['name'] as String,
        imageOriginal: json['imageOriginal'] as String,
        imageResult: json['imageResult'] as String,
        operations: (json['operations'] as List)
            .map((e) => RotationOperation.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        totalAngle: (json['totalAngle'] as num).toDouble(),
        normalizedAngle: (json['normalizedAngle'] as num).toDouble(),
        formula: json['formula'] as String,
        showTrace: json['showTrace'] as bool,
        includeDirect: json['includeDirect'] as bool,
      );
}
