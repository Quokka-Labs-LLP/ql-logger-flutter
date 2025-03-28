import 'dart:async';

class TimerService {
  static final TimerService _instance = TimerService._internal();

  TimerService._internal();

  static TimerService get instance => _instance;

  /// Timer instance for scheduling tasks.
  static Timer? timer;

  /// [minDurationInMin] sets the default minimum duration (in minutes) for starting the timer at a specific interval.
  static int minDurationInMin = 3;

  ///[startTimer] starts a timer that runs at a specified interval.
  static void startTimer(int durationInMin, {required Function() onSuccess}) {
    if (timer?.isActive ?? false) {
      return;
    }
    // If the specified duration is less than 1 minute, it defaults to minDurationInMin.
    timer = Timer.periodic(
        Duration(minutes: durationInMin < 1 ? minDurationInMin : durationInMin),
        (_) {
      onSuccess();
    });
  }
}
