import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/map_config.dart';

class CampusMap extends StatelessWidget {
  const CampusMap({
    this.center = MapConfig.campusCenter,
    this.zoom = 16,
    this.markers = const [],
    this.interactive = true,
    this.onTap,
    this.showAttribution = true,
    super.key,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final bool interactive;
  final ValueChanged<LatLng>? onTap;
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (tapPosition, point) => onTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrlTemplate,
          userAgentPackageName: MapConfig.userAgentPackageName,
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        if (showAttribution)
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
      ],
    );
  }
}

Marker campusMarker(LatLng point, {Color color = Colors.red}) {
  return Marker(
    point: point,
    width: 44,
    height: 44,
    child: Icon(Icons.location_pin, color: color, size: 44),
  );
}
