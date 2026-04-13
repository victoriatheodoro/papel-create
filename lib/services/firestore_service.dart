import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_group.dart';
import '../models/scan_result.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _groups(String uid) =>
      _db.collection('users').doc(uid).collection('groups');

  static CollectionReference<Map<String, dynamic>> _scans(String uid) =>
      _db.collection('users').doc(uid).collection('scans');

  // ─── Leitura ───────────────────────────────────────────────────────────────

  static Future<List<ActivityGroup>> loadGroups(String uid) async {
    try {
      final snap = await _groups(uid).get();
      return snap.docs
          .map((d) => ActivityGroup.fromJson(d.data()))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] Erro ao carregar grupos: $e');
      return [];
    }
  }

  static Future<List<ScanResult>> loadScans(String uid) async {
    try {
      final snap = await _scans(uid)
          .orderBy('scannedAt', descending: true)
          .get();
      return snap.docs
          .map((d) => ScanResult.fromJson(d.data()))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] Erro ao carregar scans: $e');
      return [];
    }
  }

  // ─── Escrita ───────────────────────────────────────────────────────────────

  static Future<void> saveGroups(
      String uid, List<ActivityGroup> groups) async {
    try {
      final batch = _db.batch();
      final col = _groups(uid);

      // Apaga todos e reescreve (coleção pequena, operação segura)
      final existing = await col.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (final g in groups) {
        batch.set(col.doc(g.id), g.toJson());
      }
      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] Erro ao salvar grupos: $e');
    }
  }

  static Future<void> saveScans(
      String uid, List<ScanResult> scans) async {
    try {
      final batch = _db.batch();
      final col = _scans(uid);

      final existing = await col.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (final s in scans) {
        batch.set(col.doc(s.id), s.toJson());
      }
      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] Erro ao salvar scans: $e');
    }
  }
}
