import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ActivityGroup {
  final String id;
  String name;

  ActivityGroup({
    String? id,
    required this.name,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ActivityGroup.fromJson(Map<String, dynamic> j) => ActivityGroup(
        id: j['id'] as String,
        name: j['name'] as String,
      );

  static String encodeList(List<ActivityGroup> list) =>
      jsonEncode(list.map((g) => g.toJson()).toList());

  static List<ActivityGroup> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((j) => ActivityGroup.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
