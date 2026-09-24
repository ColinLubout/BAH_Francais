import 'dart:math' as math;

/// Python's `random` module: the Mersenne Twister (MT19937), seeded as
/// `random.seed(n)` seeds it, with `random.random()`'s 53-bit doubles.
///
/// py-fsrs's fuzz tests call `random.seed(...)` and expect exact intervals;
/// this lets the port be checked against them with the same numbers.
class PythonRandom {
  PythonRandom(int seed) {
    _initByArray(_seedKey(seed));
  }

  static const _n = 624;
  static const _m = 397;
  static const _mask32 = 0xffffffff;

  final List<int> _mt = List.filled(_n, 0);
  int _index = _n + 1;

  /// `random.random()`.
  double random() {
    final a = _nextUint32() >> 5;
    final b = _nextUint32() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }

  /// `random.seed(n)` splits abs(n) into 32-bit words, least significant
  /// first.
  static List<int> _seedKey(int seed) {
    var n = seed.abs();
    final key = <int>[];
    do {
      key.add(n & _mask32);
      n >>= 32;
    } while (n > 0);
    return key;
  }

  void _initGenrand(int s) {
    _mt[0] = s & _mask32;
    for (var i = 1; i < _n; i++) {
      _mt[i] = (1812433253 * (_mt[i - 1] ^ (_mt[i - 1] >> 30)) + i) & _mask32;
    }
    _index = _n;
  }

  void _initByArray(List<int> key) {
    _initGenrand(19650218);
    var i = 1;
    var j = 0;
    for (var k = math.max(_n, key.length); k > 0; k--) {
      _mt[i] =
          ((_mt[i] ^ ((_mt[i - 1] ^ (_mt[i - 1] >> 30)) * 1664525)) +
              key[j] +
              j) &
          _mask32;
      i++;
      j++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
      if (j >= key.length) j = 0;
    }
    for (var k = _n - 1; k > 0; k--) {
      _mt[i] =
          ((_mt[i] ^ ((_mt[i - 1] ^ (_mt[i - 1] >> 30)) * 1566083941)) - i) &
          _mask32;
      i++;
      if (i >= _n) {
        _mt[0] = _mt[_n - 1];
        i = 1;
      }
    }
    _mt[0] = 0x80000000;
  }

  int _nextUint32() {
    if (_index >= _n) _twist();
    var y = _mt[_index++];
    y ^= y >> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >> 18;
    return y & _mask32;
  }

  void _twist() {
    for (var i = 0; i < _n; i++) {
      final y = (_mt[i] & 0x80000000) | (_mt[(i + 1) % _n] & 0x7fffffff);
      var next = _mt[(i + _m) % _n] ^ (y >> 1);
      if (y.isOdd) next ^= 0x9908b0df;
      _mt[i] = next;
    }
    _index = 0;
  }
}
