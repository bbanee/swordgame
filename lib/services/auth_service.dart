import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Firebase Auth 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 싱글톤 패턴
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;
  
  // 로그인 상태 확인
  bool get isLoggedIn => currentUser != null;
  
  // 사용자 UID (계정 구분용 핵심!)
  String? get uid => currentUser?.uid;
  
  // 인증 상태 변화 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // ===== 이메일 회원가입 =====
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('회원가입 실패: $e');
    }
  }
  
  // ===== 이메일 로그인 =====
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('로그인 실패: $e');
    }
  }
  
  // ===== 익명 로그인 (게스트) =====
  Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return AuthResult.success(credential.user);
    } catch (e) {
      return AuthResult.failure('게스트 로그인 실패: $e');
    }
  }
  
  // ===== 로그아웃 =====
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // ===== 비밀번호 재설정 이메일 =====
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null, message: '비밀번호 재설정 이메일을 보냈습니다');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('이메일 전송 실패: $e');
    }
  }
  
  // ===== 재인증 (이메일/비밀번호) =====
  Future<AuthResult> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return AuthResult.failure('로그인이 필요합니다');
      
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return AuthResult.success(user, message: '재인증 성공');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('재인증 실패: $e');
    }
  }
  
  // ===== 계정 삭제 =====
  Future<AuthResult> deleteAccount() async {
    try {
      await currentUser?.delete();
      return AuthResult.success(null, message: '계정이 삭제되었습니다');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResult.failure('REQUIRES_RECENT_LOGIN');  // 특수 코드
      }
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      // 문자열에서 requires-recent-login 체크
      if (e.toString().contains('requires-recent-login')) {
        return AuthResult.failure('REQUIRES_RECENT_LOGIN');
      }
      return AuthResult.failure('계정 삭제 실패: $e');
    }
  }
  
  // 에러 메시지 한글화
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다';
      case 'invalid-email':
        return '잘못된 이메일 형식입니다';
      case 'weak-password':
        return '비밀번호가 너무 약합니다 (6자 이상)';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다';
      case 'too-many-requests':
        return '너무 많은 시도입니다. 잠시 후 다시 시도하세요';
      case 'user-disabled':
        return '비활성화된 계정입니다';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 틀렸습니다';
      default:
        return '오류가 발생했습니다: $code';
    }
  }
}

// 인증 결과 클래스
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;
  final String? message;
  
  AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
    this.message,
  });
  
  factory AuthResult.success(User? user, {String? message}) {
    return AuthResult._(isSuccess: true, user: user, message: message);
  }
  
  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, errorMessage: error);
  }
}