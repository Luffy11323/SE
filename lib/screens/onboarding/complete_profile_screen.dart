// lib/screens/onboarding/complete_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/constants/app_routes.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  TimeOfDay? _selectedTime;
  bool _religiousReminders = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    _notifications.initialize(initSettings);

    // Gentle entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentGreen,
              onPrimary: Colors.black87,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textLight,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.accentGreen),
            ), dialogTheme: DialogThemeData(backgroundColor: AppColors.primaryDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> _scheduleDailyReminder(TimeOfDay time) async {
    final granted = await _requestNotificationPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please allow notifications for daily reminders"),
            backgroundColor: AppColors.warningColor,
          ),
        );
      }
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0, // notification ID (0 = daily reminder)
      "Gentle Reminder",
      "Time for quiet reflection — your journey awaits.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reflection_reminder',
          'Daily Reflection Reminder',
          channelDescription: 'Gentle daily nudge for self-reflection',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: false,
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );

  }

  Future<void> _saveProfileAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'reminderHour': _selectedTime?.hour,
        'reminderMinute': _selectedTime?.minute,
        'religiousRemindersEnabled': _religiousReminders,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Schedule real daily reminder if time is selected and reminders enabled
      if (_selectedTime != null && _religiousReminders) {
        await _scheduleDailyReminder(_selectedTime!);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong — please try again.'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              const Color(0xFF0D1525),
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      Text(
                        "Let's make this journey yours",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: AppColors.accentGreen.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Just a few gentle details to begin.",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textLight.withValues(alpha: 0.75),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Name',
                          labelStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: AppColors.cardBackground.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textLight),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'Please share your name' : null,
                      ),

                      const SizedBox(height: 24),

                      // Age field
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Your Age',
                          labelStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: AppColors.cardBackground.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textLight),
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Please enter your age';
                          final age = int.tryParse(v!);
                          if (age == null || age < 13 || age > 120) return 'Please enter a valid age';
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Reminder time picker
                      GestureDetector(
                        onTap: () => _pickTime(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedTime != null
                                  ? AppColors.accentGreen.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTime == null
                                    ? 'Choose your daily reflection time'
                                    : 'Reminder set for ${_selectedTime!.format(context)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedTime == null
                                      ? AppColors.textLight.withValues(alpha: 0.6)
                                      : AppColors.textLight,
                                ),
                              ),
                              Icon(
                                Icons.access_time_rounded,
                                color: AppColors.accentGreen.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Faith-based reminders toggle
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _religiousReminders
                                ? AppColors.accentGreen.withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Gentle faith-based encouragement",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                Switch(
                                  value: _religiousReminders,
                                  onChanged: (val) => setState(() => _religiousReminders = val),
                                  activeThumbColor: AppColors.accentGreen,
                                  inactiveThumbColor: AppColors.textLight.withValues(alpha: 0.5),
                                  inactiveTrackColor: AppColors.cardBackground,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Optional gentle reminders inspired by patience, mercy, and accountability — never rulings or judgment.",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.textLight.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _saveProfileAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 8,
                            shadowColor: AppColors.accentGreen.withValues(alpha: 0.5),
                          ),
                          child: Text(
                            "Continue My Journey",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}