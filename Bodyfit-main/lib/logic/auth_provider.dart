import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  AuthProvider() {
    _initializeTestAccount();
    _loadAuthState();
  }

  /// Initialize test account on first run
  Future<void> _initializeTestAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final testAccountExists =
        prefs.getBool('test_account_initialized') ?? false;

    if (!testAccountExists) {
      // Create test account
      await prefs.setString('auth_email', 'ammarrajput8786@gmail.com');
      await prefs.setString('auth_password', 'RanaAmmar12');
      await prefs.setString('auth_name', 'Ammar Rajput');
      await prefs.setBool('test_account_initialized', true);
      debugPrint(
          '✅ Test account created: ammarrajput8786@gmail.com / RanaAmmar12');
    }
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('auth_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _email = savedEmail;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('auth_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _email = savedEmail;
      _isAuthenticated = true;
      debugPrint('Auto-login successful: $savedEmail');
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      if (email.isEmpty || password.length < 6) {
        throw Exception('Invalid credentials');
      }

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('auth_email');
      final savedPassword = prefs.getString('auth_password');

      if (savedEmail == null || savedEmail.isEmpty) {
        throw Exception(
            'No account found with this email. Please sign up first.');
      }

      if (savedPassword == null || savedPassword.isEmpty) {
        throw Exception('Account data is incomplete. Please sign up again.');
      }

      // Check email (case-insensitive)
      if (savedEmail.toLowerCase() != email.trim().toLowerCase()) {
        throw Exception(
            'No account found with this email. Please sign up first.');
      }

      // Check password (exact match)
      if (savedPassword != password) {
        throw Exception(
            'Invalid password. Please check your password and try again.');
      }

      _email = email.trim();
      _isAuthenticated = true;
      debugPrint('Login successful: $email');
      notifyListeners();
    } catch (e) {
      debugPrint('Login error: $e');
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      if (name.isEmpty || email.isEmpty || password.length < 6) {
        throw Exception('Please fill all fields (password 6+ chars)');
      }

      final prefs = await SharedPreferences.getInstance();
      final existingEmail = prefs.getString('auth_email');
      if (existingEmail != null &&
          existingEmail.toLowerCase() == email.trim().toLowerCase()) {
        throw Exception('An account with this email already exists');
      }

      // Save user credentials
      await prefs.setString('auth_email', email.trim());
      await prefs.setString('auth_password', password);
      await prefs.setString('auth_name', name);

      debugPrint('Signup successful: $email');

      _email = email.trim();
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Signup error: $e');
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      // Clear session state but keep credentials for future login
      _email = null;
      _isAuthenticated = false;

      debugPrint('User logged out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      throw Exception('Logout failed');
    }
  }

  // Method to completely delete account
  Future<void> deleteAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_email');
      await prefs.remove('auth_password');
      await prefs.remove('auth_name');

      _email = null;
      _isAuthenticated = false;

      debugPrint('Account deleted successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Account deletion error: $e');
      throw Exception('Account deletion failed');
    }
  }
}
