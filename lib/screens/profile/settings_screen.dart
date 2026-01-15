// lib/screens/profile/settings_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay? _reminderTime;
  bool _religiousReminders = false;
  bool _isLoading = true;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _loadUserSettings();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
  }

  Future<void> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final hour = data['reminderHour'] as int?;
        final minute = data['reminderMinute'] as int?;
        setState(() {
          _reminderTime = (hour != null && minute != null)
              ? TimeOfDay(hour: hour, minute: minute)
              : null;
          _religiousReminders = data['religiousRemindersEnabled'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading settings: $e');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
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

    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
      await _saveAndRescheduleReminder(picked);
    }
  }

  Future<void> _saveAndRescheduleReminder(TimeOfDay time) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'reminderHour': time.hour,
        'reminderMinute': time.minute,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Only re-schedule if faith reminders are enabled
      if (_religiousReminders) {
        await _scheduleDailyReminder(time);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder time updated'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update reminder'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleFaithReminders(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'religiousRemindersEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _religiousReminders = value);

      if (value && _reminderTime != null) {
        await _scheduleDailyReminder(_reminderTime!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Faith reminders enabled'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      } else {
        await _notifications.cancel(0); // cancel the daily reminder
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Faith reminders disabled'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update setting'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> _scheduleDailyReminder(TimeOfDay time) async {
    final granted = await _requestNotificationPermission();
    if (!granted || !_religiousReminders) return;

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
      0,
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentGreen)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Settings",
          style: TextStyle(color: AppColors.textLight, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Reminder time
          ListTile(
            title: Text(
              "Daily Reflection Time",
              style: TextStyle(color: AppColors.textLight, fontSize: 16),
            ),
            subtitle: Text(
              _reminderTime == null
                  ? "Not set"
                  : _reminderTime!.format(context),
              style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
            ),
            trailing: Icon(Icons.chevron_right, color: AppColors.accentGreen),
            onTap: () => _pickTime(context),
          ),

          const Divider(color: AppColors.cardBackground),

          // Faith reminders toggle
          SwitchListTile(
            title: Text(
              "Gentle Faith-Based Encouragement",
              style: TextStyle(color: AppColors.textLight, fontSize: 16),
            ),
            subtitle: Text(
              "Optional reminders inspired by mercy & patience",
              style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
            ),
            value: _religiousReminders,
            activeThumbColor: AppColors.accentGreen,
            onChanged: _toggleFaithReminders,
          ),

          const Divider(color: AppColors.cardBackground),

          // Logout
          ListTile(
            title: Text(
              "Logout",
              style: TextStyle(color: AppColors.textLight, fontSize: 16),
            ),
            trailing: Icon(Icons.logout_rounded, color: AppColors.accentGreen),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}