import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser => _firebaseAuth.currentUser;

  bool get isLoggedIn => currentUser != null;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ============================================================
  // INITIALIZE GOOGLE SIGN-IN
  // ============================================================

  Future<void> _initializeGoogleSignIn() async {
    if (_initialized) {
      return;
    }

    // Android configuration comes automatically from:
    // android/app/google-services.json
    await _googleSignIn.initialize();

    _initialized = true;
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _initializeGoogleSignIn();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In did not return an ID token.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      return await _firebaseAuth.signInWithCredential(
        credential,
      );
    } on GoogleSignInException catch (e) {
      throw Exception(
        'Google Sign-In error: ${e.code} - ${e.description}',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        'Firebase Auth error: ${e.code} - ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Google authentication failed: $e',
      );
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _initializeGoogleSignIn();

    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnectGoogleAccount() async {
    await _initializeGoogleSignIn();

    await _googleSignIn.disconnect();
    await _firebaseAuth.signOut();
  }
}
