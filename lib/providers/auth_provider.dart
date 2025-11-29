import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../core/utils/logger.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    AppLogger.info('AuthProvider initializing');
    _authService.authStateChanges.listen((event) async {
      if (event.session != null) {
        AppLogger.info('Auth state changed: authenticated');
        await _loadUserProfile();
        _status = AuthStatus.authenticated;
      } else {
        AppLogger.info('Auth state changed: unauthenticated');
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });

    if (_authService.isAuthenticated) {
      await _loadUserProfile();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    try {
      AppLogger.debug('Loading user profile');
      _user = await _userService.getCurrentUserProfile();
      AppLogger.success('User profile loaded');
    } catch (e) {
      AppLogger.error('Load user profile error', e);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
    String? role,
    String? societyId,
    List<String>? interests,
  }) async {
    try {
      AppLogger.info('SignUp attempt: $email');
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        societyId: societyId,
        interests: interests,
      );

      await _loadUserProfile();
      _status = AuthStatus.authenticated;
      AppLogger.success('SignUp successful: $email');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('SignUp failed', e);
      _error = _authService.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('SignIn attempt: $email');
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      await _authService.signIn(email: email, password: password);

      await _loadUserProfile();
      _status = AuthStatus.authenticated;
      AppLogger.success('SignIn successful: $email');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('SignIn failed', e);
      _error = _authService.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      AppLogger.info('SignOut attempt');
      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      AppLogger.success('SignOut successful');
      notifyListeners();
    } catch (e) {
      AppLogger.error('SignOut failed', e);
      _error = _authService.getErrorMessage(e);
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      AppLogger.info('Password reset request: $email');
      _error = null;
      await _authService.sendPasswordResetEmail(email);
      AppLogger.success('Password reset email sent');
      return true;
    } catch (e) {
      AppLogger.error('Password reset failed', e);
      _error = _authService.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      AppLogger.info('Password update attempt');
      _error = null;
      await _authService.updatePassword(newPassword);
      AppLogger.success('Password updated');
      return true;
    } catch (e) {
      AppLogger.error('Password update failed', e);
      _error = _authService.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    AppLogger.debug('Refreshing user profile');
    await _loadUserProfile();
    notifyListeners();
  }

  void updateUser(UserModel user) {
    AppLogger.debug('User model updated locally');
    _user = user;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
