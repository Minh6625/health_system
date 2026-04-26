import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:latlong2/latlong.dart';

/// Embedded OSM map showing the patient's last known GPS pin.
///
/// Falls back to a "Vị trí không xác định" placeholder when the SOS event
/// does not have valid latitude/longitude (e.g. the patient never granted
/// location permission, or the device lost a GPS fix).
class EmergencySOSMapBlock extends StatelessWidget {
  final SOSEventModel sos;
  final double height;

  const EmergencySOSMapBlock({
    super.key,
    required this.sos,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: AppShadows.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        child: Container(
          color: AppColors.strokeSoft,
          child:
              (sos.location.latitude != null && sos.location.longitude != null)
              ? FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      sos.location.latitude!,
                      sos.location.longitude!,
                    ),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.healthguard',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            sos.location.latitude!,
                            sos.location.longitude!,
                          ),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.critical,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.gapSm),
                    Text(
                      'Map view',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Vị trí không xác định',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
