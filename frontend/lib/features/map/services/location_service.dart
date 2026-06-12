import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'border_alert_engine.dart';
import '../../../services/sync_manager.dart';

class LocationState {
  final LatLng currentPosition;
  final double speedInKnots;
  final double heading;
  final double distanceToBorder;
  final bool isNearBorder;
  final bool isInsideRestrictedZone;
  final List<LatLng> breadcrumbs;
  final String locationErrorMessage;

  LocationState({
    required this.currentPosition,
    this.speedInKnots = 0.0,
    this.heading = 0.0,
    this.distanceToBorder = 999.0,
    this.isNearBorder = false,
    this.isInsideRestrictedZone = false,
    this.breadcrumbs = const [],
    this.locationErrorMessage = '',
  });

  LocationState copyWith({
    LatLng? currentPosition,
    double? speedInKnots,
    double? heading,
    double? distanceToBorder,
    bool? isNearBorder,
    bool? isInsideRestrictedZone,
    List<LatLng>? breadcrumbs,
    String? locationErrorMessage,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      speedInKnots: speedInKnots ?? this.speedInKnots,
      heading: heading ?? this.heading,
      distanceToBorder: distanceToBorder ?? this.distanceToBorder,
      isNearBorder: isNearBorder ?? this.isNearBorder,
      isInsideRestrictedZone: isInsideRestrictedZone ?? this.isInsideRestrictedZone,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      locationErrorMessage: locationErrorMessage ?? this.locationErrorMessage,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  StreamSubscription<Position>? _positionSubscription;
  final Ref _ref;

  LocationNotifier(this._ref)
      : super(LocationState(
          currentPosition: const LatLng(9.10, 79.55), // Starting coordinates (safe waters)
          breadcrumbs: [const LatLng(9.10, 79.55)],
        )) {
    _startTracking();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(locationErrorMessage: 'Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(locationErrorMessage: 'Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        locationErrorMessage: 'Location permissions are permanently denied, we cannot request permissions.',
      );
      return;
    }

    // Configure tracking settings optimized for volatile marine boundaries
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Update instantly on any change
    );

    // Fetch initial location instantly on launch so the map doesn't get stuck on start coordinates
    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final initialPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      
      // Calculate speed and border check for initial position
      final isInsideRestricted = BorderAlertEngine.isInsidePolygon(initialPoint);
      final distBorder = BorderAlertEngine.getDistanceToBorder(initialPoint);
      final isNear = distBorder < 5.0;

      state = state.copyWith(
        currentPosition: initialPoint,
        speedInKnots: initialPosition.speed * 1.94384,
        heading: initialPosition.heading,
        distanceToBorder: distBorder,
        isNearBorder: isNear,
        isInsideRestrictedZone: isInsideRestricted,
        breadcrumbs: [initialPoint],
      );
    } catch (e) {
      debugPrint("Failed to fetch initial GPS coordinate: $e");
      state = state.copyWith(locationErrorMessage: "GPS Initial Lock Failed: $e");
    }

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      
      // Calculate speed in knots (1 m/s = 1.94384 knots)
      final speedKnots = position.speed * 1.94384;
      final headingValue = position.heading;

      // Local Geo-fencing checks
      final isInsideRestricted = BorderAlertEngine.isInsidePolygon(newPoint);
      final distBorder = BorderAlertEngine.getDistanceToBorder(newPoint);
      final isNear = distBorder < 5.0; // warning triggers if < 5km from border

      // Breadcrumb history
      final updatedBreadcrumbs = List<LatLng>.from(state.breadcrumbs)..add(newPoint);

      // Trigger automatic sync logging
      _ref.read(syncProvider.notifier).queueGps(
        newPoint.latitude,
        newPoint.longitude,
        speedKnots,
        DateTime.now().toIso8601String(),
      );

      state = state.copyWith(
        currentPosition: newPoint,
        speedInKnots: speedKnots,
        heading: headingValue,
        distanceToBorder: distBorder,
        isNearBorder: isNear,
        isInsideRestrictedZone: isInsideRestricted,
        breadcrumbs: updatedBreadcrumbs,
        locationErrorMessage: '',
      );
    }, onError: (e) {
      state = state.copyWith(locationErrorMessage: e.toString());
    });
  }

  void setManualPosition(LatLng position) {
    state = state.copyWith(currentPosition: position);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref);
});
