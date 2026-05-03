import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  static const _kEmail = 'local_auth_email';
  static const _kPassword = 'local_auth_password';
  static const _kName = 'local_auth_name';
  static const _kLoggedIn = 'local_auth_logged_in';

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kEmail, email.toLowerCase());
    await prefs.setString(_kPassword, password);
    await prefs.setBool(_kLoggedIn, true);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_kEmail);
    final storedPassword = prefs.getString(_kPassword);

    final ok = storedEmail == email.toLowerCase() && storedPassword == password;
    if (ok) {
      await prefs.setBool(_kLoggedIn, true);
    }
    return ok;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmail);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, false);
  }
}
