// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class NotificationService {
  /// Solicita permissão para notificações ao usuário.
  /// Retorna true se concedida.
  static Future<bool> requestPermission() async {
    final permission = web.Notification.permission;
    if (permission == 'granted') return true;
    if (permission == 'denied') return false;

    final result = await web.Notification.requestPermission().toDart;
    return result == 'granted';
  }

  static bool get isSupported =>
      web.Notification.permission != 'undefined';

  static bool get isGranted =>
      web.Notification.permission == 'granted';

  /// Exibe uma notificação com [title] e [body].
  static void show(String title, {String body = ''}) {
    if (!isGranted) return;
    web.Notification(
      title,
      web.NotificationOptions(body: body),
    );
  }
}
