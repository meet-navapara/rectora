/// Two 62-bit chunks stored as non-negative Dart integers.
///
/// 62 bits is the largest width that stays inside a VM small integer, so the
/// overlap test used by both solvers stays on fast fixed-width arithmetic.
/// Together the chunks cover 124 cells (enough for a 10×10 or 11×11 board).
class Bits {
  const Bits(this.a, this.b);

  final int a;
  final int b;

  static const zero = Bits(0, 0);
  static const maxIndex = 123;

  Bits set(int index) {
    if (index < 0 || index > maxIndex) {
      throw RangeError.range(index, 0, maxIndex, 'index');
    }
    if (index < 62) {
      return Bits(a | (1 << index), b);
    }
    return Bits(a, b | (1 << (index - 62)));
  }

  bool test(int index) {
    if (index < 62) return (a & (1 << index)) != 0;
    return (b & (1 << (index - 62))) != 0;
  }

  bool intersects(Bits other) => (a & other.a) != 0 || (b & other.b) != 0;

  Bits union(Bits other) => Bits(a | other.a, b | other.b);

  int get count => _bitCount(a) + _bitCount(b);

  @override
  bool operator ==(Object other) =>
      other is Bits && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

int _bitCount(int n) {
  var count = 0;
  var x = n;
  while (x != 0) {
    x &= x - 1;
    count++;
  }
  return count;
}
