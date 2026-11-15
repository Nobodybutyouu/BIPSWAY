import 'package:latlong2/latlong.dart';

class MapConfig {
  MapConfig._();

  static const tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgentPackageName = 'com.example.bipsway';
  static const campusCenter = LatLng(11.56285, 124.40055);
  static const campusCenterNote = 'BiPSU Main Campus';
}
