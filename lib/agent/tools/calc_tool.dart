import 'tool.dart';

/// Safe arithmetic calculator (restricted expression grammar).
class CalculateTool extends JarvisTool {
  @override
  String get name => 'calculate_tool';

  @override
  String get description =>
      'Evaluate a math expression in a restricted way (literals and operators only). '
      'Example: 2 + 2 * 3';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description':
                'Valid arithmetic expression (numbers, + - * / parentheses).',
          },
        },
        'required': ['expression'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final expression = arguments['expression']?.toString() ?? '';
    try {
      final result = SafeCalculator.evaluate(expression);
      if (result is double) {
        final rounded = double.parse(result.toStringAsFixed(2));
        return rounded.toString();
      }
      return result.toString();
    } catch (e) {
      throw ArgumentError('Error while evaluating expression: $e');
    }
  }
}

/// Recursive-descent evaluator for `+ - * /` and parentheses only.
class SafeCalculator {
  SafeCalculator._(this._src);

  final String _src;
  int _i = 0;

  static num evaluate(String expression) {
    final calc = SafeCalculator._(expression.trim());
    if (calc._src.isEmpty) {
      throw FormatException('Empty expression');
    }
    final value = calc._parseExpression();
    calc._skipWs();
    if (calc._i < calc._src.length) {
      throw FormatException('Unexpected input at ${calc._i}');
    }
    return value;
  }

  void _skipWs() {
    while (_i < _src.length && _src[_i].trim().isEmpty) {
      _i++;
    }
  }

  num _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipWs();
      if (_match('+')) {
        value = value + _parseTerm();
      } else if (_match('-')) {
        value = value - _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  num _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipWs();
      if (_match('*')) {
        value = value * _parseFactor();
      } else if (_match('/')) {
        final rhs = _parseFactor();
        if (rhs == 0) throw ArgumentError('Division by zero');
        value = value / rhs;
      } else {
        break;
      }
    }
    return value;
  }

  num _parseFactor() {
    _skipWs();
    if (_match('+')) return _parseFactor();
    if (_match('-')) return -_parseFactor();
    if (_match('(')) {
      final value = _parseExpression();
      _skipWs();
      if (!_match(')')) throw FormatException('Expected )');
      return value;
    }
    return _parseNumber();
  }

  num _parseNumber() {
    _skipWs();
    final start = _i;
    while (_i < _src.length &&
        (RegExp(r'[0-9.]').hasMatch(_src[_i]))) {
      _i++;
    }
    if (start == _i) {
      throw FormatException('Expected number at $_i');
    }
    final raw = _src.substring(start, _i);
    if (raw.contains('.')) {
      return double.parse(raw);
    }
    return int.parse(raw);
  }

  bool _match(String ch) {
    _skipWs();
    if (_i < _src.length && _src[_i] == ch) {
      _i++;
      return true;
    }
    return false;
  }
}
