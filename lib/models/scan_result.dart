import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class TaskItem {
  String id;
  String text;
  bool completed;
  bool priority;
  bool inProgress;
  DateTime? dueDate;
  String? todoistId; // ID da tarefa no Todoist (null = não sincronizada)

  TaskItem({
    String? id,
    required this.text,
    this.completed = false,
    this.priority = false,
    this.inProgress = false,
    this.dueDate,
    this.todoistId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'completed': completed,
        'priority': priority,
        'inProgress': inProgress,
        'dueDate': dueDate?.toIso8601String(),
        'todoistId': todoistId,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        text: j['text'] as String,
        completed: j['completed'] as bool? ?? false,
        priority: j['priority'] as bool? ?? false,
        inProgress: j['inProgress'] as bool? ?? false,
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'] as String)
            : null,
        todoistId: j['todoistId'] as String?,
      );
}

class EventItem {
  String id;
  String text;
  String? date;
  String? time;

  EventItem({
    String? id,
    required this.text,
    this.date,
    this.time,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'date': date,
        'time': time,
      };

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j['id'] as String,
        text: j['text'] as String,
        date: j['date'] as String?,
        time: j['time'] as String?,
      );
}

class ScanResult {
  final String id;
  final List<String> imagePaths;
  List<TaskItem> tasks;
  List<EventItem> events;
  final DateTime scannedAt;
  String rawText;
  String? groupId;

  ScanResult({
    String? id,
    required this.imagePaths,
    required this.tasks,
    required this.events,
    required this.rawText,
    DateTime? scannedAt,
    this.groupId,
  })  : id = id ?? _uuid.v4(),
        scannedAt = scannedAt ?? DateTime.now();

  // Merge outro ScanResult neste (adiciona tasks/events sem duplicar)
  void merge(ScanResult other) {
    final existingTexts = tasks.map((t) => t.text.toLowerCase()).toSet();
    for (final t in other.tasks) {
      if (!existingTexts.contains(t.text.toLowerCase())) tasks.add(t);
    }
    final existingEvents = events.map((e) => e.text.toLowerCase()).toSet();
    for (final e in other.events) {
      if (!existingEvents.contains(e.text.toLowerCase())) events.add(e);
    }
    rawText = '$rawText\n${other.rawText}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePaths': imagePaths,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'rawText': rawText,
        'scannedAt': scannedAt.toIso8601String(),
        'groupId': groupId,
      };

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        id: j['id'] as String,
        imagePaths: List<String>.from(j['imagePaths'] as List),
        tasks: (j['tasks'] as List)
            .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
            .toList(),
        events: (j['events'] as List)
            .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        rawText: j['rawText'] as String,
        scannedAt: DateTime.parse(j['scannedAt'] as String),
        groupId: j['groupId'] as String?,
      );

  static String encodeList(List<ScanResult> list) =>
      jsonEncode(list.map((s) => s.toJson()).toList());

  static List<ScanResult> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((j) => ScanResult.fromJson(j as Map<String, dynamic>)).toList();
  }
}
