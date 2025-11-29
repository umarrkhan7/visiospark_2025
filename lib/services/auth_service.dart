import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';

class AuthService {
  final _auth = SupabaseConfig.auth;
  final _client = SupabaseConfig.client;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? role,
    String? societyId,
    List<String>? interests,
  }) async {
    try {
      AppLogger.info('SignUp request', email);
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          'society_id': societyId,
          'interests': interests,
        },
      );

      if (response.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _ensureProfileExists(
          response.user!,
          fullName,
          role: role,
          societyId: societyId,
          interests: interests,
        );
      }

      AppLogger.success('User signed up', response.user?.email);
      return response;
    } catch (e) {
      AppLogger.error('Sign up error', e);
      rethrow;
    }
  }

  Future<void> _ensureProfileExists(
    User user,
    String? fullName, {
    String? role,
    String? societyId,
    List<String>? interests,
  }) async {
    try {
      AppLogger.debug('Checking profile for user', user.id);
      
      final existingProfile = await _client
          .from(SupabaseConfig.profilesTable)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        AppLogger.info('Creating profile for user', user.id);
        await _client.from(SupabaseConfig.profilesTable).insert({
          'id': user.id,
          'email': user.email,
          'full_name': fullName,
          'role': role ?? 'student',
          'society_id': societyId,
          'interests': interests,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        AppLogger.success('Profile created successfully', user.email);
      } else {
        AppLogger.info('Profile already exists', user.email);
      }
    } catch (e) {
      AppLogger.error('Profile creation error', e);
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('SignIn request: $email');
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.success('User signed in: ${response.user?.email}');
      return response;
    } catch (e) {
      AppLogger.error('Sign in error', e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      AppLogger.info('SignOut request');
      await _auth.signOut();
      AppLogger.success('User signed out');
    } catch (e) {
      AppLogger.error('Sign out error', e);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      AppLogger.info('Password reset request: $email');
      await _auth.resetPasswordForEmail(email);
      AppLogger.success('Password reset email sent to $email');
    } catch (e) {
      AppLogger.error('Password reset error', e);
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      AppLogger.info('Password update request');
      await _auth.updateUser(UserAttributes(password: newPassword));
      AppLogger.success('Password updated');
    } catch (e) {
      AppLogger.error('Update password error', e);
      rethrow;
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      AppLogger.info('Email update request: $newEmail');
      await _auth.updateUser(UserAttributes(email: newEmail));
      AppLogger.success('Email update request sent');
    } catch (e) {
      AppLogger.error('Update email error', e);
      rethrow;
    }
  }

  String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }
}
