import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:self_evaluator/modules/self_eval/self_eval_screen.dart';
import 'firebase_options.dart';
import 'package:self_evaluator/screens/login_screen.dart';
import 'package:self_evaluator/screens/signup_screen.dart';
import 'package:self_evaluator/screens/self_eval/self_eval_screen.dart';
import 'package:self_evaluator/screens/pool/my_pools_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Self Evaluator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return snapshot.hasData
                      ? const DashboardScreen()
                      : const LoginScreen();
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/evaluate': (context) => const SelfEvalScreen(category: 'Default'),
        '/results': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ResultsScreen(
            currentScores: args['scores'],
            userId: args['userId'] ?? '',
          );
        },
        '/pools': (context) => const MyPoolsScreen(),
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/evaluate',
                arguments: {'category': 'Personal'},
              ),
              child: const Text('Start Evaluation'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/pools'),
              child: const Text('Feedback Pools'),
            ),
          ],
        ),
      ),
    );
  }
}
