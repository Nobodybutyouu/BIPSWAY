import 'dart:ui';

import '../../models/room.dart';

RoomPin normalizedPinFromOffset(Offset offset, Size imageSize) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return const RoomPin(x: 0.5, y: 0.5);
  }
  return RoomPin(
    x: (offset.dx / imageSize.width).clamp(0.0, 1.0),
    y: (offset.dy / imageSize.height).clamp(0.0, 1.0),
  );
}

Offset offsetFromNormalizedPin(RoomPin pin, Size imageSize) {
  return Offset(pin.x * imageSize.width, pin.y * imageSize.height);
}
