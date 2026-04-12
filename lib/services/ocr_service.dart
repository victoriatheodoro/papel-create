import 'package:image_picker/image_picker.dart';
import '../models/scan_result.dart';

import 'ocr_service_mobile.dart'
    if (dart.library.html) 'ocr_service_web.dart' as platform;

class OcrService {
  // Processa um XFile (compatível web e mobile)
  Future<ScanResult> processFile(XFile file) async {
    final rawText = await platform.extractText(file);

    return ScanResult(
      imagePaths: [file.path],
      tasks: _parseTasks(rawText),
      events: _parseEvents(rawText),
      rawText: rawText,
    );
  }

  List<TaskItem> _parseTasks(String text) {
    final tasks = <TaskItem>[];

    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;

      // [x] concluída — vem antes de [ ] para não conflitar
      final completed = RegExp(r'^\[x\]\s*(.+)', caseSensitive: false).firstMatch(t);
      if (completed != null) {
        final (cleanText, dueDate) = _extractDueDate(completed.group(1)!.trim());
        tasks.add(TaskItem(text: cleanText, completed: true, dueDate: dueDate));
        continue;
      }

      // [ ] pendente — aceita espaço, underline ou traço
      final pending = RegExp(r'^\[[\s_\-]\]\s*(.+)').firstMatch(t);
      if (pending != null) {
        final rawText = pending.group(1)!.trim();
        final hasPriority = rawText.startsWith('!') || rawText.endsWith('!');
        final (cleanText, dueDate) = _extractDueDate(rawText.replaceAll('!', '').trim());
        tasks.add(TaskItem(
          text: cleanText,
          priority: hasPriority,
          dueDate: dueDate,
        ));
        continue;
      }

      // ! prioridade
      final priority = RegExp(r'^!\s+(.+)').firstMatch(t);
      if (priority != null) {
        final (cleanText, dueDate) = _extractDueDate(priority.group(1)!.trim());
        tasks.add(TaskItem(text: cleanText, priority: true, dueDate: dueDate));
        continue;
      }

      // ~ em andamento
      final inProgress = RegExp(r'^~\s+(.+)').firstMatch(t);
      if (inProgress != null) {
        final (cleanText, dueDate) = _extractDueDate(inProgress.group(1)!.trim());
        tasks.add(TaskItem(text: cleanText, inProgress: true, dueDate: dueDate));
      }
    }

    return tasks;
  }

  /// Extrai sufixo de data no formato " - dd/mm" ou " - dd/mm/aaaa" do texto.
  /// Retorna o texto limpo e o DateTime correspondente (ou null).
  (String, DateTime?) _extractDueDate(String text) {
    final match =
        RegExp(r'\s*-\s*(\d{1,2}/\d{1,2}(?:/\d{2,4})?)$').firstMatch(text);
    if (match == null) return (text, null);
    final cleanText = text.substring(0, match.start).trim();
    final dueDate = _parseDate(match.group(1)!);
    return (cleanText, dueDate);
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      int year;
      if (parts.length >= 3) {
        year = int.parse(parts[2]);
        if (year < 100) year += 2000;
      } else {
        year = DateTime.now().year;
      }
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  List<EventItem> _parseEvents(String text) {
    final events = <EventItem>[];

    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final event = RegExp(r'^\(\s*\)\s*(.+)').firstMatch(t);
      if (event != null) {
        final raw = event.group(1)!.trim();
        final dateMatch = RegExp(r'\d{1,2}/\d{1,2}(?:/\d{2,4})?').firstMatch(raw);
        events.add(EventItem(
          text: dateMatch != null
              ? raw.replaceFirst(dateMatch.group(0)!, '').trim()
              : raw,
          date: dateMatch?.group(0),
        ));
      }
    }

    return events;
  }

  void dispose() {}
}
