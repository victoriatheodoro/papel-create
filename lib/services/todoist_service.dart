import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';
import '../models/activity_group.dart';

class TodoistService {
  static const _base = 'https://api.todoist.com/rest/v2';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('todoist_token') ?? '';
    return token.isEmpty ? null : token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ─── Push: envia tarefas do app para o Todoist ────────────────────────────

  /// Cria ou atualiza tarefas no Todoist.
  /// Retorna quantas foram enviadas com sucesso.
  Future<int> push(List<ScanResult> history, Function() onSave) async {
    final token = await getToken();
    if (token == null) throw Exception('TODOIST_NO_TOKEN');

    int count = 0;
    for (final scan in history) {
      for (final task in scan.tasks) {
        if (task.completed && task.todoistId == null) continue; // ignora concluídas sem ID
        if (task.todoistId != null) {
          // Já existe no Todoist — sincronizar status de conclusão
          if (task.completed) {
            await _closeTask(token, task.todoistId!);
            count++;
          }
          continue;
        }
        // Tarefa nova — criar no Todoist
        final id = await _createTask(token, task);
        if (id != null) {
          task.todoistId = id;
          count++;
        }
      }
    }
    await onSave();
    return count;
  }

  Future<String?> _createTask(String token, TaskItem task) async {
    final body = <String, dynamic>{'content': task.text};
    if (task.priority) body['priority'] = 4; // p1 no Todoist = priority 4
    if (task.dueDate != null) {
      body['due_date'] =
          '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}';
    }

    final resp = await http.post(
      Uri.parse('$_base/tasks'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['id'] as String?;
    }
    return null;
  }

  Future<void> _closeTask(String token, String todoistId) async {
    await http.post(
      Uri.parse('$_base/tasks/$todoistId/close'),
      headers: _headers(token),
    );
  }

  // ─── Pull: importa tarefas do Todoist para o app ──────────────────────────

  /// Busca tarefas ativas do Todoist e importa as que ainda não existem no app.
  /// Retorna um novo [ScanResult] com as tarefas importadas (ou null se vazio).
  Future<ScanResult?> pull(
    List<ScanResult> history,
    List<ActivityGroup> groups,
  ) async {
    final token = await getToken();
    if (token == null) throw Exception('TODOIST_NO_TOKEN');

    final resp = await http.get(
      Uri.parse('$_base/tasks'),
      headers: _headers(token),
    );
    if (resp.statusCode != 200) {
      throw Exception('Todoist erro ${resp.statusCode}');
    }

    final remoteTasks = jsonDecode(resp.body) as List;

    // IDs já conhecidos localmente
    final knownIds = <String>{};
    for (final scan in history) {
      for (final t in scan.tasks) {
        if (t.todoistId != null) knownIds.add(t.todoistId!);
      }
    }

    // Grupo "Todoist" — cria se não existir
    ActivityGroup? todoistGroup;
    for (final g in groups) {
      if (g.name == 'Todoist') {
        todoistGroup = g;
        break;
      }
    }

    final newTasks = <TaskItem>[];
    for (final remote in remoteTasks) {
      final remoteId = remote['id'] as String;
      if (knownIds.contains(remoteId)) continue;

      final task = TaskItem(
        text: remote['content'] as String,
        priority: (remote['priority'] as int? ?? 1) >= 4,
        todoistId: remoteId,
      );

      // Prazo
      final due = remote['due'] as Map<String, dynamic>?;
      if (due != null && due['date'] != null) {
        task.dueDate = DateTime.tryParse(due['date'] as String);
      }

      newTasks.add(task);
    }

    if (newTasks.isEmpty) return null;

    return ScanResult(
      imagePaths: [],
      tasks: newTasks,
      events: [],
      rawText: 'Importado do Todoist',
      groupId: todoistGroup?.id,
    );
  }
}
