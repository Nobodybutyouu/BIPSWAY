import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:bipsway/core/utils/room_pin_utils.dart';

void main() {
  test('normalizes and denormalizes room pin coordinates', () {
    const size = Size(1000, 500);
    final pin = normalizedPinFromOffset(const Offset(250, 125), size);

    expect(pin.x, 0.25);
    expect(pin.y, 0.25);
    expect(offsetFromNormalizedPin(pin, size), const Offset(250, 125));
  });

  test('clamps room pin coordinates to the image bounds', () {
    final pin = normalizedPinFromOffset(const Offset(-20, 600), const Size(100, 100));

    expect(pin.x, 0);
    expect(pin.y, 1);
  });
}
