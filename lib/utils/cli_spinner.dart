import 'dart:async';
import 'dart:io';

class SimpleSpinner {
  final List<String> _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  int _frameIndex = 0;
  late Timer _timer;
  bool _isRunning = false;

  final String _green = '\x1B[32m'; // Green color
  final String _red = '\x1B[31m';   // Red color
  final String _reset = '\x1B[0m';  // Reset color to default

  void start(String message) {
    if (_isRunning) return; // Prevent starting the spinner if it's already running

    _isRunning = true;
    stdout.write(message);

    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      stdout.write('\r${_spinnerFrames[_frameIndex]} $message');
      _frameIndex = (_frameIndex + 1) % _spinnerFrames.length; // Loop through spinner frames
    });
  }

  // Stop the spinner and show custom success or failure message with colors
  void stop({bool isSuccess = true, String successMessage = 'Done!', String failureMessage = 'Failed!'}) {
    if (!_isRunning) return; // If spinner isn't running, no need to stop

    _isRunning = false;
    _timer.cancel();

    // Use the provided messages, or default ones if empty
    String message = isSuccess ? successMessage : failureMessage;

    if (isSuccess) {
      stdout.write('\r$_green✔ $message$_reset         \n');
    } else {
      stdout.write('\r$_red❌ $message$_reset        \n');
    }
  }
}
