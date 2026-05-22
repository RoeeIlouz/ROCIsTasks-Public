import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userCredential = await authService.signInWithGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (userCredential != null) {
        // Navigation is handled by the auth stream listener in main or wrapper
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signInFailed)));
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Navigation is handled by the auth stream listener
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signInFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidEmail)),
      );
      return;
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.sendPasswordResetEmail(email);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordResetEmailSent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Image(
                  image: AssetImage('assets/images/logo.png'),
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.welcomeToApp,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.signInToSync,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return l10n.invalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return l10n.passwordTooShort;
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: Text(l10n.forgotPassword),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _signInWithEmail,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(l10n.signIn),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: Text(l10n.signInWithGoogle),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(l10n.dontHaveAccount),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
