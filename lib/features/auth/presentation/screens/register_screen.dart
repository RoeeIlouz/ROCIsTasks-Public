import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      await authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        // Navigation is handled by the auth stream listener
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createAccount),
      ),
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
                  width: 80,
                  height: 80,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPassword,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(l10n.register),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(l10n.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
