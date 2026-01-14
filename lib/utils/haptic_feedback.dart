import 'package:vibration/vibration.dart';

class Haptic {
  static Future<void> light() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 10);
    }
  }

  static Future<void> error() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 500);
    }
  }
    // Add these methods
  static Future<void> selection() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 10); // light tap
    }
  }

  static Future<void> success() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 50, 100, 50]); // soft success
    }
  }

  static Future<void> warning() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 200);
    }
  }
}

// Usage: Replace all direct Vibration calls with:
// await Haptic.success();
