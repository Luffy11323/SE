// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _lastReflectionDate;
  bool _religiousReminders = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      final lastDate = data['lastReflectionDate'] as Timestamp?;
      setState(() {
        _lastReflectionDate = lastDate != null
            ? DateFormat('MMM d, yyyy').format(lastDate.toDate())
            : null;
        _religiousReminders = data['religiousRemindersEnabled'] ?? false;
      });
    }
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Subtle welcome / nudge
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                Icon(
                  Icons.self_improvement_rounded,
                  size: 100,
                  color: AppColors.accentGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 32),
                Text(
                  "Welcome back, ${_getUserFirstName()}",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_lastReflectionDate != null)
                  Text(
                    "Last reflection: $_lastReflectionDate",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  )
                else
                  Text(
                    "Your journey is waiting whenever you're ready.",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),

          const Spacer(flex: 2),

          // The only prominent action — big, gentle, inviting
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.reflectionHome);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGreen.withValues(alpha: 0.9),
                    const Color(0xFF00CC66),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Begin Today's Reflection",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "A quiet moment just for you",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primaryDark.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  String _getUserFirstName() {
    // Placeholder — later read from Firestore or auth displayName
    return "Friend"; // Replace with real name when you fetch it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(), // Home / Reflection entry
          const Center(child: Text("History coming soon", style: TextStyle(color: AppColors.textLight))), // Placeholder for now
          const Center(child: Text("Settings coming soon", style: TextStyle(color: AppColors.textLight))), // Placeholder
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground.withValues(alpha: 0.8),
        selectedItemColor: AppColors.accentGreen,
        unselectedItemColor: AppColors.textLight.withValues(alpha: 0.6),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}