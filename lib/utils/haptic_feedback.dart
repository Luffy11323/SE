import 'package:vibration/vibration.dart';

class Haptic {
  static Future<void> light() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 10);
    }
  }

  static Future<void> success() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: [0, 100, 50, 100]);
    }
  }

  static Future<void> error() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 500);
    }
  }
}

// Usage: Replace all direct Vibration calls with:
// await Haptic.success();
