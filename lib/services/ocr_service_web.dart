import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> extractText(XFile file) async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('gemini_api_key') ?? '';

  if (apiKey.isEmpty) {
    throw Exception('API_KEY_MISSING');
  }

  final bytes = await file.readAsBytes();
  final base64Image = base64Encode(bytes);
  final mimeType = _detectMime(file.name);

  const prompt = '''
Você é um assistente especializado em leitura de anotações manuscritas em português.
Analise esta imagem de um caderno ou folha com anotações à mão.

Extraia SOMENTE os itens que usam estes símbolos:
- [ ] = tarefa pendente
- [x] = tarefa concluída (o x pode ser maiúsculo ou minúsculo)
- ( ) = evento ou reunião
- ! = prioridade alta (pode aparecer antes de qualquer item)
- ~ = tarefa em andamento (já começou mas não terminou)

Ignore todo texto que não tenha esses símbolos.

IMPORTANTE: Se uma tarefa tiver uma data no formato "- dd/mm" ou "- dd/mm/aaaa" no final do texto, MANTENHA essa data no campo "text" da tarefa exatamente como está. Ex: "Reunião com cliente - 10/04/2026".

Retorne APENAS um JSON válido, sem nenhum texto adicional, no formato:
{
  "tasks": [
    {"text": "descrição da tarefa", "completed": false, "priority": false, "inProgress": false},
    {"text": "tarefa com prazo - 10/04/2026", "completed": false, "priority": false, "inProgress": false}
  ],
  "events": [
    {"text": "descrição do evento sem a data", "date": "dd/mm ou dd/mm/aaaa"}
  ]
}

Se não encontrar itens com os símbolos, retorne: {"tasks": [], "events": []}
''';

  final response = await http.post(
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            },
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 1024},
    }),
  );

  if (response.statusCode == 400) {
    final body = jsonDecode(response.body);
    final msg = body['error']?['message'] ?? 'API key inválida';
    throw Exception('Gemini: $msg');
  }
  if (response.statusCode == 429) {
    try {
      final body = jsonDecode(response.body);
      final msg = body['error']?['message'] ?? 'limite atingido';
      throw Exception('RATE_LIMIT: $msg');
    } catch (_) {
      throw Exception('RATE_LIMIT: ${response.body}');
    }
  }
  if (response.statusCode != 200) {
    throw Exception('Gemini erro ${response.statusCode}: ${response.body}');
  }

  final body = jsonDecode(response.body);
  final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

  if (text == null || text.isEmpty) {
    throw Exception('Gemini não retornou conteúdo.');
  }

  return _geminiJsonToSymbols(text.trim());
}

// Converte o JSON do Gemini em texto com símbolos para o parser do OcrService
String _geminiJsonToSymbols(String geminiJson) {
  try {
    final clean = geminiJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final data = jsonDecode(clean) as Map<String, dynamic>;
    final buffer = StringBuffer();

    for (final t in (data['tasks'] as List? ?? [])) {
      final text = (t['text'] as String? ?? '').trim();
      final completed = t['completed'] as bool? ?? false;
      final priority = t['priority'] as bool? ?? false;
      if (text.isEmpty) continue;
      final inProgress = t['inProgress'] as bool? ?? false;
      if (completed) {
        buffer.writeln('[x] $text');
      } else if (priority) {
        buffer.writeln('! $text');
      } else if (inProgress) {
        buffer.writeln('~ $text');
      } else {
        buffer.writeln('[ ] $text');
      }
    }

    for (final e in (data['events'] as List? ?? [])) {
      final text = (e['text'] as String? ?? '').trim();
      final date = e['date'] as String?;
      if (text.isEmpty) continue;
      final hasDate = date != null && date != 'null' && date.isNotEmpty;
      buffer.writeln('( ) $text${hasDate ? ' $date' : ''}');
    }

    return buffer.toString();
  } catch (err) {
    debugPrint('Erro ao parsear JSON do Gemini: $err\nRaw: $geminiJson');
    return '';
  }
}

String _detectMime(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
