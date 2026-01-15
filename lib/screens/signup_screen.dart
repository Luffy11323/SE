import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  String? _name;
  int? _age;
  String? _password;
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _signUpUser() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _password!,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': _emailController.text.trim(), // ✅ Email now stored
        'name': _name,
        'age': _age,
        'reminderTimeHour': _reminderTime?.hour,
        'reminderTimeMinute': _reminderTime?.minute,
      });

      await scheduleReminder();

      if (mounted) {
        context.go('/login');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    }
  }

  Future<void> scheduleReminder() async {
    if (_reminderTime == null) return;

    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _reminderTime!.hour,
      _reminderTime!.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Reminder',
      'This is your reminder after signup!',
      tzScheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exact,
      matchDateTimeComponents: DateTimeComponents.time,
    );


    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${_reminderTime!.format(context)}!'),
        ),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _signUpUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your email'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your name'
                    : null,
                onSaved: (value) => _name = value,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your age'
                    : null,
                onSaved: (value) => _age = int.tryParse(value ?? ''),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your password'
                    : null,
                onSaved: (value) => _password = value,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _selectReminderTime(context),
                child: const Text('Select Reminder Time'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
