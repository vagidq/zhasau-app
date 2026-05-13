import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'register_screen.dart';
import 'main_shell.dart';
import '../models/app_store.dart';
import '../services/auth_service.dart';
import '../services/local_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final LocalAuthService _localAuthService = LocalAuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text.trim();

      try {
        await _authService.signIn(email, password);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapAuthError(e))),
        );
        return;
      } catch (e) {
        final msg = e.toString();
        final isCredentialLike = msg.contains('invalid-credential') ||
            msg.contains('wrong-password') ||
            msg.contains('user-not-found') ||
            msg.contains('invalid-login-credentials') ||
            msg.contains('INVALID_LOGIN_CREDENTIALS');
        if (isCredentialLike) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_mapAuthError(e))),
          );
          return;
        }
        // Сеть / плагин — пробуем локальный fallback
        final loggedInLocal = await _localAuthService.signIn(
          email: email,
          password: password,
        );
        if (loggedInLocal) {
          await AppStore.instance.resetSession();
          AppStore.instance.initializeEmptyProfile();
          final localName = await _localAuthService.getName();
          if (localName != null && localName.isNotEmpty) {
            AppStore.instance.userProfile.name = localName;
          }
          AppStore.instance.userProfile.email = email;
          AppStore.instance.refreshUI();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainShell(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
          return;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapAuthError(e))),
        );
        return;
      }

      try {
        await AppStore.instance.resetSession();
        await AppStore.instance.loadUserData();
        await _localAuthService.signUp(
          name: AppStore.instance.userProfile.name,
          email: email,
          password: password,
        );
      } catch (e, st) {
        debugPrint('Login post-FirebaseAuth: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Вход в аккаунт выполнен, но не удалось подготовить данные приложения. '
              'Проверьте интернет и доступ к Firestore. '
              '(${_shortError(e)})',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e, st) {
      debugPrint('Login unexpected: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа: ${_mapAuthError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _shortError(Object e) {
    final s = e.toString();
    if (s.length > 120) return '${s.substring(0, 117)}…';
    return s;
  }

  String _mapAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Пользователь не найден';
        case 'wrong-password':
          return 'Неверный пароль';
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Неверный email или пароль';
        case 'invalid-email':
          return 'Некорректный email';
        case 'user-disabled':
          return 'Этот аккаунт отключён';
        case 'too-many-requests':
          return 'Слишком много попыток, попробуйте позже';
        case 'operation-not-allowed':
          return 'В Firebase Console включите «Email/Password» (Authentication → Sign-in method).';
        case 'network-request-failed':
          return 'Нет подключения к сети';
        case 'internal-error':
          return 'Временная ошибка сервера Google. Повторите вход позже.';
        case 'web-context-cancelled':
        case 'web-storage-unsupported':
          return 'Ошибка окна входа. Закройте и откройте экран снова.';
      }
      final m = error.message?.trim();
      if (m != null && m.isNotEmpty) return m;
      return 'Ошибка входа (код: ${error.code})';
    }
    final message = error.toString();
    if (message.contains('user-not-found')) return 'Пользователь не найден';
    if (message.contains('wrong-password')) return 'Неверный пароль';
    if (message.contains('invalid-credential') ||
        message.contains('invalid-login-credentials') ||
        message.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Неверный email или пароль';
    }
    if (message.contains('invalid-email')) return 'Некорректный email';
    if (message.contains('user-disabled')) return 'Этот аккаунт отключён';
    if (message.contains('too-many-requests')) {
      return 'Слишком много попыток, попробуйте позже';
    }
    if (message.contains('operation-not-allowed') ||
        message.contains('sign-in provider is disabled')) {
      return 'В Firebase Console включите способ входа «Email/Password».';
    }
    if (message.contains('network-request-failed') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
      return 'Нет подключения к сети';
    }
    if (message.contains('permission-denied')) {
      return 'Нет доступа к данным (Firestore). Проверьте правила в консоли Firebase.';
    }
    if (message.contains('TimeoutException') || message.contains('timeout')) {
      return 'Превышено время ожидания. Проверьте сеть.';
    }
    return 'Не удалось войти (${_shortError(error)})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // Logo + Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Z',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Добро пожаловать!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Войдите, чтобы продолжить',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x07000000), blurRadius: 16,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email
                          _label('Почта'),
                          const SizedBox(height: 8),
                          _inputField(
                            controller: _emailCtrl,
                            hint: 'example@mail.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Введите почту';
                              }
                              final email = v.trim();
                              final emailRegex =
                                  RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
                              if (!emailRegex.hasMatch(email)) {
                                return 'Только латиница и корректный формат email';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9@._%+\-]'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Password
                          _label('Пароль'),
                          const SizedBox(height: 8),
                          _inputField(
                            controller: _passCtrl,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Введите пароль';
                              }
                              if (v.length < 6) {
                                return 'Минимум 6 символов';
                              }
                              if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(v)) {
                                return 'Пароль только на латинице/ASCII';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\x21-\x7E]'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {},
                              child: Text(
                                'Забыли пароль?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Войти',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.borderDark, thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'или',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.borderDark, thickness: 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Register link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const RegisterScreen(),
                            transitionDuration:
                                const Duration(milliseconds: 350),
                            transitionsBuilder: (_, anim, __, child) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOut)),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textMuted),
                          children: [
                            const TextSpan(text: 'Нет аккаунта? '),
                            TextSpan(
                              text: 'Зарегистрироваться',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textLight, fontSize: 15),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.bgMain,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.red, width: 2),
        ),
        errorStyle: TextStyle(color: AppColors.red, fontSize: 12),
      ),
    );
  }
}
