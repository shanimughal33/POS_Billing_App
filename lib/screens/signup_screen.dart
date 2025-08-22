import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;
  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _info;
  bool _loading = false;
  bool _showConfetti = false;

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKeys[0].currentState?.validate() ?? false) {
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 1) {
      if (_formKeys[1].currentState?.validate() ?? false) {
        setState(() => _currentStep++);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _signUpWithEmailPassword() async {
    if (!(_formKeys[1].currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _info = null;
    });
    final firstName = _firstNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(firstName);
      if (!mounted) return;
      setState(() => _showConfetti = true);
      await Future.delayed(Duration(seconds: 2));

      // Wait for Firebase Auth state to be properly established
      await Future.delayed(Duration(milliseconds: 500));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveUserUid(user.uid);
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(
        () => _info = 'Error: ${e.message ?? 'Unknown error occurred.'}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _info = 'Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _loading = true;
      _info = null;
    });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in aborted');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() => _showConfetti = true);
      await Future.delayed(Duration(seconds: 2));

      // Wait for Firebase Auth state to be properly established
      await Future.delayed(Duration(milliseconds: 500));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveUserUid(user.uid);
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _info = 'Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _animatedStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _currentStep == index;
        return AnimatedContainer(
          duration: Duration(milliseconds: 350),
          margin: EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 22 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? Color(0xFF1976D2)
                : Color(0xFF1976D2).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Color(0xFF1976D2).withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Color(0xFF0A2342) : Colors.white;
    final primaryColor = Color(0xFF1976D2);
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_showConfetti)
                Positioned.fill(
                  child: Lottie.asset(
                    'assets/progress.json', // Replace with your confetti/checkmark Lottie if available
                    repeat: false,
                  ),
                ),
              Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 300,
                        child: Lottie.asset(
                          'assets/progress.json',
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _animatedStepIndicator(),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 320,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _currentStep == 0
                              ? Form(
                                  key: _formKeys[0],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    key: ValueKey(0),
                                    children: [
                                      TextFormField(
                                        controller: _firstNameController,
                                        decoration: InputDecoration(
                                          labelText: 'First Name',
                                          prefixIcon: Icon(
                                            Icons.person,
                                            color: isDark ? Colors.white : Color(0xFF1976D2),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.white : Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          fillColor: isDark ? Colors.white10 : Colors.grey[50],
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 14),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your first name';
                                          }
                                          if (value.trim().length < 2) {
                                            return 'First name must be at least 2 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _lastNameController,
                                        decoration: InputDecoration(
                                          labelText: 'Last Name',
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                            color: isDark ? Colors.white : Color(0xFF1976D2),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.white : Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          fillColor: isDark ? Colors.white10 : Colors.grey[50],
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 14),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your last name';
                                          }
                                          if (value.trim().length < 2) {
                                            return 'Last name must be at least 2 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: Icon(
                                            Icons.email,
                                            color: isDark ? Colors.white : Color(0xFF1976D2),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.white : Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          fillColor: isDark ? Colors.white10 : Colors.grey[50],
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        style: TextStyle(fontSize: 14),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!RegExp(
                                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                          ).hasMatch(value)) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : Form(
                                  key: _formKeys[1],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    key: ValueKey(1),
                                    children: [
                                      TextFormField(
                                        controller: _passwordController,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: Icon(
                                            Icons.lock,
                                            color: isDark ? Colors.white : Color(0xFF1976D2),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.white : Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          fillColor: isDark ? Colors.white10 : Colors.grey[50],
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        obscureText: true,
                                        style: TextStyle(fontSize: 14),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        decoration: InputDecoration(
                                          labelText: 'Confirm Password',
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: isDark ? Colors.white : Color(0xFF1976D2),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.white : Color(0xFF1976D2),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          fillColor: isDark ? Colors.white10 : Colors.grey[50],
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                        ),
                                        obscureText: true,
                                        style: TextStyle(fontSize: 14),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          if (value !=
                                              _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),

                      if (_currentStep == 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Color(0xFF1976D2) : Colors.white,
                                foregroundColor: isDark ? Colors.white : Color(0xFF1976D2),
                                shape: StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                                elevation: 8,
                                shadowColor: Color(
                                  0xFF1976D2,
                                ).withOpacity(0.18),
                                textStyle: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back,
                                    color: isDark ? Colors.white : Color(0xFF1976D2),
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text('Back'),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : Color(0xFF1976D2),
                                shape: StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                elevation: 3,
                                textStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Next',
                                    style: TextStyle(color: isDark ? Colors.black : Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_currentStep == 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _prevStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Color(0xFF1976D2) : Colors.white,
                                foregroundColor: isDark ? Colors.white : Color(0xFF1976D2),
                                shape: StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                elevation: 8,
                                shadowColor: Color(
                                  0xFF1976D2,
                                ).withOpacity(0.18),
                                textStyle: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back,
                                    color: isDark ? Colors.white : Color(0xFF1976D2),
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text('Back'),
                                ],
                              ),
                            ),
                            _loading
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: isDark ? Colors.white : Color(0xFF1976D2),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _signUpWithEmailPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white : Color(0xFF1976D2),
                                      shape: StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 12,
                                      ),
                                      elevation: 3,
                                      textStyle: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: isDark ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            "Already have an account? Login",
                            style: TextStyle(
                              color: isDark ? Colors.white : Color(0xFF1976D2),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _info!,
                          style: TextStyle(
                            color: _info!.startsWith('Error')
                                ? Colors.red
                                : Colors.green,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
