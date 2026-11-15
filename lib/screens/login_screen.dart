import 'package:flutter/material.dart';

import '../widgets/scenora_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.reason,
    required this.onLogin,
    required this.onRegister,
    required this.onGoogleLogin,
  });

  final String reason;
  final Future<String?> Function(String email, String password) onLogin;
  final Future<String?> Function(String username, String email, String password)
  onRegister;
  final Future<String?> Function() onGoogleLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const orange = Color(0xFFFF6A00);
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _registerMode = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = _registerMode
        ? await widget.onRegister(
            _usernameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          )
        : await widget.onLogin(
            _emailController.text.trim(),
            _passwordController.text,
          );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: Icon(icon, color: orange),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF0B0F0E),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: .14)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: orange, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _CinematicBackdrop(),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    32,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      tooltip: 'Continue as guest',
                      onPressed: () => Navigator.pop(context, false),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: .48),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ScenoraLogo(size: 82),
                  const SizedBox(height: 18),
                  const _Wordmark(),
                  const SizedBox(height: 10),
                  const _Tagline(),
                  const SizedBox(height: 18),
                  Text(
                    'Join a community of movie & series lovers.\nShare reviews, ratings and your passion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xE6080B0A),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: orange.withValues(alpha: .17),
                          blurRadius: 28,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ModeTab(
                                  label: 'Login',
                                  selected: !_registerMode,
                                  onTap: _loading
                                      ? null
                                      : () => setState(() {
                                          _registerMode = false;
                                          _error = null;
                                        }),
                                ),
                              ),
                              Expanded(
                                child: _ModeTab(
                                  label: 'Sign Up',
                                  selected: _registerMode,
                                  onTap: _loading
                                      ? null
                                      : () => setState(() {
                                          _registerMode = true;
                                          _error = null;
                                        }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.reason,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .68),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_registerMode) ...[
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration(
                                'Username',
                                Icons.alternate_email_rounded,
                              ),
                              validator: (value) =>
                                  RegExp(
                                    r'^[a-zA-Z0-9_]{3,24}$',
                                  ).hasMatch(value?.trim() ?? '')
                                  ? null
                                  : 'Use 3-24 letters, numbers, or underscores',
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(color: Colors.white),
                            decoration: _decoration(
                              'Email address',
                              Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return email.isNotEmpty && email.contains('@')
                                  ? null
                                  : 'Enter a valid email address';
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            style: const TextStyle(color: Colors.white),
                            decoration: _decoration(
                              'Password',
                              Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').length >= 8
                                ? null
                                : 'Password must be at least 8 characters',
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A1111),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: orange.withValues(
                                  alpha: .45,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 8,
                                shadowColor: orange,
                              ),
                              child: _loading
                                  ? const SizedBox.square(
                                      dimension: 23,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _registerMode
                                          ? 'Create account'
                                          : 'Login',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text('Continue browsing as guest'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'SC'),
        TextSpan(
          text: 'E',
          style: TextStyle(color: _LoginScreenState.orange),
        ),
        TextSpan(text: 'NORA'),
      ],
    ),
    style: TextStyle(
      color: Colors.white,
      fontSize: 38,
      fontWeight: FontWeight.w900,
      letterSpacing: 7,
    ),
  );
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'DISCOVER.  '),
        TextSpan(
          text: 'WATCH.',
          style: TextStyle(color: _LoginScreenState.orange),
        ),
        TextSpan(text: '  SHARE.'),
      ],
    ),
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.8,
      fontSize: 12,
    ),
  );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? _LoginScreenState.orange : Colors.white12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? _LoginScreenState.orange : Colors.white60,
          fontSize: 16,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF17110D), Colors.black, Color(0xFF07110E)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: -80,
          right: -90,
          child: _Glow(color: _LoginScreenState.orange, size: 290),
        ),
        const Positioned(
          bottom: 100,
          left: -130,
          child: _Glow(color: Color(0xFF8B2500), size: 330),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .26),
                  Colors.black.withValues(alpha: .72),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
      ),
    ),
  );
}
