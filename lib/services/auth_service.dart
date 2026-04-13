import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static Stream<User?> get userStream => _auth.authStateChanges();

  static Future<User?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      final result = await _auth.signInWithPopup(provider);
      return result.user;
    } catch (e) {
      // ignore: avoid_print
      print('[Auth] Erro no login com Google: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
