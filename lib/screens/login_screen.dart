import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/widgets/custom_button.dart';
import 'package:self_evaluator/screens/dashboard_screen.dart';
import 'package:self_evaluator/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SocialProvider { google, facebook }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> handleSocialLogin(SocialProvider provider) async {
    try {
      OAuthCredential? credential;

      if (provider == SocialProvider.google) {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
      } else {
        final result = await FacebookAuth.instance.login();
        if (result.status != LoginStatus.success ||
            result.accessToken == null) {
          _showMessage(
              'Facebook login failed: ${result.message ?? "Unknown error"}');
          return;
        }
        credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
      }

      // ignore: unnecessary_null_comparison
      if (credential != null) {
        await FirebaseAuth.instance.signInWithCredential(credential);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _checkAndNavigate(user);
        }
      }
    } catch (e) {
      _showMessage('Social Sign-In error: $e');
    }
  }

  Future<void> _checkAndNavigate(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/complete-profile');
      }
    }
  }

  void _handleEmailLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                AppStrings.loginTitle,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: AppStrings.emailHint,
                  prefixIcon: Icon(Icons.email, color: color),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: AppStrings.passwordHint,
                  prefixIcon: Icon(Icons.lock, color: color),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: AppStrings.loginButton,
                onPressed: _handleEmailLogin,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: () => handleSocialLogin(SocialProvider.google),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.facebook),
                label: const Text('Sign in with Facebook'),
                onPressed: () => handleSocialLogin(SocialProvider.facebook),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                child: const Text('Don\'t have an account? Sign Up!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
