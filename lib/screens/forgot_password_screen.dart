import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _info;
  bool _loading = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _info = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _info = 'Password reset link sent! Check your email.';
        _loading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = 'Error: ${e.message}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _info = 'An unexpected error occurred.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
        titleTextStyle: TextStyle(
          color: Colors.blue[800],
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Forgot Your Password?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ).animate().fade(duration: 500.ms).slideY(begin: -0.5),
                const SizedBox(height: 16),
                Text(
                  'Enter your email below to receive a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ).animate().fade(delay: 200.ms),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blue[800]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ).animate().fade(delay: 400.ms).slideX(begin: -0.5),
                const SizedBox(height: 32),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Send Reset Link'),
                      ).animate().fade(delay: 600.ms).scale(),
                if (_info != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _info!.startsWith('Error')
                          ? Colors.red
                          : Colors.green,
                      fontSize: 16,
                    ),
                  ).animate().fade(),
                ],
              ],
            ).animate().slideY(begin: 0.5, duration: 500.ms),
          ),
        ),
      ),
    );
  }
}
