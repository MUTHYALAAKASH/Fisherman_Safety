import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../map/services/location_service.dart';

class WeatherData {
  final double windSpeedKnots;
  final double waveHeightMeters;
  final double temperatureCelsius;
  final double pressureHpa;
  final int humidityPercent;
  final String windDirectionDescription;
  final String advisory;
  final bool isSafeToSail;
  final bool isFromApi;

  WeatherData({
    required this.windSpeedKnots,
    required this.waveHeightMeters,
    required this.temperatureCelsius,
    required this.pressureHpa,
    required this.humidityPercent,
    required this.windDirectionDescription,
    required this.advisory,
    required this.isSafeToSail,
    this.isFromApi = false,
  });

  factory WeatherData.mock() {
    return WeatherData(
      windSpeedKnots: 12.4,
      waveHeightMeters: 1.2,
      temperatureCelsius: 31.0,
      pressureHpa: 1013.0,
      humidityPercent: 74,
      windDirectionDescription: "Blowing North-West",
      advisory: "ADVISORY: SAFE TO SAIL. Conditions are optimal within 50 nautical miles.",
      isSafeToSail: true,
      isFromApi: false,
    );
  }
}

class WeatherNotifier extends StateNotifier<AsyncValue<WeatherData>> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  WeatherNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    state = const AsyncValue.loading();
    try {
      final locationState = _ref.read(locationProvider);
      final lat = locationState.currentPosition.latitude;
      final lon = locationState.currentPosition.longitude;

      // 1. Fetch main forecast from Open-Meteo
      final forecastUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m,wind_direction_10m';
      final forecastRes = await _dio.get(forecastUrl);

      double temp = 31.0;
      double windSpeedKts = 12.4;
      double pressure = 1013.0;
      int humidity = 74;
      int windDirDeg = 315;

      if (forecastRes.statusCode == 200 && forecastRes.data['current'] != null) {
        final current = forecastRes.data['current'];
        temp = (current['temperature_2m'] as num?)?.toDouble() ?? temp;
        humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? humidity;
        pressure = (current['surface_pressure'] as num?)?.toDouble() ?? pressure;
        
        // Open-Meteo wind speed is in km/h by default. Convert to Knots (1 km/h = 0.539957 knots)
        final windKmh = (current['wind_speed_10m'] as num?)?.toDouble() ?? 23.0;
        windSpeedKts = windKmh * 0.539957;

        windDirDeg = (current['wind_direction_10m'] as num?)?.toInt() ?? windDirDeg;
      }

      // Convert wind direction degree to compass description
      final windDesc = _getWindDirectionDescription(windDirDeg);

      // 2. Fetch wave height from Open-Meteo Marine API
      double waveHeight = 1.2;
      try {
        final marineUrl = 'https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon&current=wave_height';
        final marineRes = await _dio.get(marineUrl);
        if (marineRes.statusCode == 200 && marineRes.data['current'] != null) {
          waveHeight = (marineRes.data['current']['wave_height'] as num?)?.toDouble() ?? waveHeight;
        }
      } catch (e) {
        debugPrint("Marine API (wave height) unavailable for this coordinate: $e. Falling back to default.");
      }

      // 3. Compute dynamic safety advisory
      bool isSafe = true;
      String advisoryMessage = "ADVISORY: SAFE TO SAIL. Conditions are optimal.";
      
      if (windSpeedKts > 22.0 || waveHeight > 2.5) {
        isSafe = false;
        advisoryMessage = "ADVISORY: DANGER - ROUGH SEAS! Extremely high winds ($windSpeedKts KTS) and swells detected. Avoid sailing!";
      } else if (windSpeedKts > 15.0 || waveHeight > 1.8) {
        isSafe = true; // still sailable but caution needed
        advisoryMessage = "ADVISORY: CAUTION - MODERATE WINDS. Waves up to $waveHeight meters. Exercise caution.";
      }

      state = AsyncValue.data(WeatherData(
        windSpeedKnots: windSpeedKts,
        waveHeightMeters: waveHeight,
        temperatureCelsius: temp,
        pressureHpa: pressure,
        humidityPercent: humidity,
        windDirectionDescription: windDesc,
        advisory: advisoryMessage,
        isSafeToSail: isSafe,
        isFromApi: true,
      ));
    } catch (err, stack) {
      debugPrint("Error fetching weather from API: $err. Falling back to mock data.");
      // Graceful fallback to mock data on network error
      state = AsyncValue.data(WeatherData.mock());
    }
  }

  String _getWindDirectionDescription(int degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return "Blowing North";
    if (degrees >= 22.5 && degrees < 67.5) return "Blowing North-East";
    if (degrees >= 67.5 && degrees < 112.5) return "Blowing East";
    if (degrees >= 112.5 && degrees < 157.5) return "Blowing South-East";
    if (degrees >= 157.5 && degrees < 202.5) return "Blowing South";
    if (degrees >= 202.5 && degrees < 247.5) return "Blowing South-West";
    if (degrees >= 247.5 && degrees < 292.5) return "Blowing West";
    return "Blowing North-West";
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, AsyncValue<WeatherData>>((ref) {
  return WeatherNotifier(ref);
});
