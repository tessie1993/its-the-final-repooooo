import 'dart:math';

/// Visits every queue entry once per shuffle cycle and remembers the actual
/// listening order, so Previous and Next retrace the same songs.
class ShuffleOrder {
  ShuffleOrder({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<int> _history = [];
  final List<int> _remaining = [];
  int _cursor = -1;
  int _length = 0;

  void reset(int length, int current) {
    _length = length;
    _history.clear();
    _remaining.clear();
    _cursor = -1;
    if (current >= 0 && current < length) {
      _history.add(current);
      _cursor = 0;
    }
    _refill(current);
  }

  void _refill(int current) {
    _remaining
      ..clear()
      ..addAll(List.generate(_length, (index) => index)
          .where((index) => index != current))
      ..shuffle(_random);
  }

  int? next({required bool repeatAll}) {
    if (_cursor + 1 < _history.length) return _history[++_cursor];
    if (_remaining.isEmpty) {
      if (!repeatAll || _length == 0) return null;
      if (_length == 1) return 0;
      _refill(_cursor < 0 ? -1 : _history[_cursor]);
    }
    final next = _remaining.removeLast();
    _history.add(next);
    _cursor++;
    // Keep an ample previous-track trail without growing forever on repeat.
    if (_history.length > 500) {
      _history.removeAt(0);
      _cursor--;
    }
    return next;
  }

  int? previous() => _cursor > 0 ? _history[--_cursor] : null;

  bool get hasNext => _cursor + 1 < _history.length || _remaining.isNotEmpty;
  bool get hasPrevious => _cursor > 0;
}
