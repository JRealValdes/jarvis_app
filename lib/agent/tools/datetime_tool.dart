import 'tool.dart';

/// Returns the current local date and time with weekday.
class CurrentDateTimeTool extends JarvisTool {
  @override
  String get name => 'current_date_time_tool';

  @override
  String get description =>
      'Return the current date and time with weekday on the device.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': <String, dynamic>{},
        'additionalProperties': false,
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[now.weekday - 1];
    final formatted =
        '${_pad(now.year, 4)}-${_pad(now.month, 2)}-${_pad(now.day, 2)} '
        '${_pad(now.hour, 2)}:${_pad(now.minute, 2)}:${_pad(now.second, 2)}';
    return 'Today is $weekday, and the current date and time is: $formatted';
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
