import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/sync_manager.dart';
import '../../services/location_service.dart';
import '../../services/border_alert_engine.dart';
import '../../../../services/voice_assistant_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _warningAnimController;

  @override
  void initState() {
    super.initState();
    _warningAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _warningAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final syncState = ref.watch(syncProvider);
    final voiceState = ref.watch(voiceAssistantProvider);

    // Reactive voice alerts for restricted border crossings
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.isNearBorder && !(previous?.isNearBorder ?? false)) {
        ref.read(voiceAssistantProvider.notifier).speak(
          "Warning! Approaching restricted maritime border. You are ${next.distanceToBorder.toStringAsFixed(1)} kilometers from the boundary. Please turn back."
        );
      }
    });

    // Reactive voice triggers for SOS redirection
    ref.listen<VoiceState>(voiceAssistantProvider, (previous, next) {
      final words = next.lastWords.toLowerCase();
      if (words.contains('sos') || words.contains('help') || words.contains('emergency')) {
        context.push(AppRouter.sosPath);
      }
    });

    // Auto-center camera when a new point is received
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(locationState.currentPosition, 13.0);
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap integration
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: locationState.currentPosition,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fisherman.safety',
              ),
              
              // Draw restricted boundary polygon
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: BorderAlertEngine.boundaryPolygon,
                    color: AppColors.crimsonAlert.withOpacity(0.18),
                    borderColor: AppColors.crimsonAlert,
                    borderStrokeWidth: 3.0,
                    isFilled: true,
                  ),
                ],
              ),

              // Draw breadcrumbs trail representing historic tracking
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: locationState.breadcrumbs,
                    color: AppColors.aquamarine,
                    strokeWidth: 4.5,
                  ),
                ],
              ),

              // Glowing boat position marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: locationState.currentPosition,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic breathing light aura
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.aquamarine.withOpacity(0.35),
                          ),
                        ),
                        // Inner icon core
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.oceanBlue,
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: AppColors.sunlightHighContrast,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. High Proximity Crimson Border Flashing Warning
          if (locationState.isNearBorder)
            AnimatedBuilder(
              animation: _warningAnimController,
              builder: (context, child) {
                return IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.crimsonAlert.withOpacity(_warningAnimController.value),
                        width: 8.0,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Voice Assistant Floating Control Panel (Top Right overlay)
          Positioned(
            top: 60,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  ref.read(voiceAssistantProvider.notifier).toggleActive();
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardNavy,
                    border: Border.all(
                      color: voiceState.isActive
                          ? (voiceState.isListening ? AppColors.safetyGreen : AppColors.aquamarine)
                          : AppColors.oceanBlue,
                      width: 2.0,
                    ),
                    boxShadow: voiceState.isActive
                        ? [
                            BoxShadow(
                              color: (voiceState.isListening ? AppColors.safetyGreen : AppColors.aquamarine).withOpacity(0.35),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : const [
                            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                  ),
                  child: Center(
                    child: Icon(
                      voiceState.isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: voiceState.isActive
                          ? (voiceState.isListening ? AppColors.safetyGreen : AppColors.sunlightHighContrast)
                          : AppColors.textMuted,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating HUD panels
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // TOP HEADERS: Warning Panel & Sync notifier
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active Location Error Alert
                      if (locationState.locationErrorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.crimsonAlert.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "GPS CONNECTION STATUS",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      locationState.locationErrorMessage,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Active Border Warning Alert
                      if (locationState.isNearBorder)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: AppColors.activeAlertGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.translate('borderWarning'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${AppLocalizations.translate('borderDistance')}${locationState.distanceToBorder.toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Offline/Online sync indicator banner
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        decoration: BoxDecoration(
                          color: syncState.isOffline 
                              ? AppColors.warnings.withOpacity(0.95)
                              : AppColors.oceanNavy.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: syncState.isOffline ? AppColors.warnings : AppColors.cardNavy,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              syncState.isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                              color: AppColors.sunlightHighContrast,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                syncState.isOffline
                                    ? '${AppLocalizations.translate('offlineSync')}${syncState.pendingGpsCount}'
                                    : 'Secured Connection Active. Sync in real-time.',
                                style: const TextStyle(
                                  color: AppColors.sunlightHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (syncState.isOffline)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                onPressed: () {
                                  // Manually trigger reconnect check
                                  ref.read(syncProvider.notifier).setConnectionStatus(false);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // BOTTOM PANEL: Gauges HUD & Action Buttons
                  Column(
                    children: [
                      // HUD Gauges Row
                      Row(
                        children: [
                          // Knots Gauge Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardNavy.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.oceanBlue, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'SPEED',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${locationState.speedInKnots.toStringAsFixed(1)} KTS',
                                    style: const TextStyle(
                                      color: AppColors.aquamarine,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Heading Gauge Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardNavy.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.oceanBlue, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'HEADING',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${locationState.heading.toStringAsFixed(0)}° N',
                                    style: const TextStyle(
                                      color: AppColors.aquamarine,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),

                      // Quick Action Buttons Panel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Settings Button
                          FloatingActionButton(
                            heroTag: 'settingsBtn',
                            backgroundColor: AppColors.cardNavy,
                            foregroundColor: AppColors.skyBlue,
                            shape: const CircleBorder(),
                            onPressed: () {
                              context.push(AppRouter.profilePath);
                            },
                            child: const Icon(Icons.settings_rounded, size: 26),
                          ),

                          // Chat Button
                          FloatingActionButton(
                            heroTag: 'chatBtn',
                            backgroundColor: AppColors.cardNavy,
                            foregroundColor: AppColors.skyBlue,
                            shape: const CircleBorder(),
                            onPressed: () {
                              context.push('/chat');
                            },
                            child: const Icon(Icons.chat_bubble_rounded, size: 26),
                          ),
                          
                          // Massive SOS Warning Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.crimsonAlert,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              side: const BorderSide(color: Colors.white, width: 1.5),
                            ),
                            onPressed: () {
                              context.push(AppRouter.sosPath);
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.translate('sosButton').replaceFirst('HOLD ', ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Weather Button
                          FloatingActionButton(
                            heroTag: 'weatherBtn',
                            backgroundColor: AppColors.cardNavy,
                            foregroundColor: AppColors.skyBlue,
                            shape: const CircleBorder(),
                            onPressed: () {
                              context.push(AppRouter.weatherPath);
                            },
                            child: const Icon(Icons.cloudy_snowing, size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
