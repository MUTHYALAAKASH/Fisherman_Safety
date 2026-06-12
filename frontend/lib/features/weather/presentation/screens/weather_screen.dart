import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../services/weather_service.dart';
import '../../../../services/voice_assistant_service.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          AppLocalizations.translate('weather').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
            tooltip: "Speak weather advisory",
            onPressed: () {
              weatherState.maybeWhen(
                data: (weather) {
                  final advisoryText = "Weather report. "
                      "Safety Advisory: ${weather.isSafeToSail ? 'It is safe to sail' : 'Rough seas warning, sailing is not recommended.'} "
                      "Wind speed is ${weather.windSpeedKnots.toStringAsFixed(1)} knots. "
                      "Wave height is ${weather.waveHeightMeters.toStringAsFixed(1)} meters. "
                      "Temperature is ${weather.temperatureCelsius.toStringAsFixed(0)} degrees. "
                      "${weather.advisory}";
                  ref.read(voiceAssistantProvider.notifier).speak(advisoryText);
                },
                orElse: () {
                  ref.read(voiceAssistantProvider.notifier).speak("Weather data is not loaded yet.");
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ref.read(weatherProvider.notifier).fetchWeather();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: weatherState.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.aquamarine),
                SizedBox(height: 16),
                Text(
                  "Fetching real-time marine weather...",
                  style: TextStyle(color: AppColors.skyBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Text(
              "Error loading weather: $err",
              style: const TextStyle(color: AppColors.crimsonAlert),
            ),
          ),
          data: (weather) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Safety Advisor Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (weather.isSafeToSail ? AppColors.safetyGreen : AppColors.crimsonAlert).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: weather.isSafeToSail ? AppColors.safetyGreen : AppColors.crimsonAlert, 
                        width: 2
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          weather.isSafeToSail ? Icons.check_circle_rounded : Icons.gpp_bad_rounded, 
                          color: weather.isSafeToSail ? AppColors.safetyGreen : AppColors.crimsonAlert, 
                          size: 50
                        ),
                        const SizedBox(height: 12),
                        Text(
                          weather.isSafeToSail ? "ADVISORY: SAFE TO SAIL" : "ADVISORY: DANGER - ROUGH SEAS",
                          style: TextStyle(
                            color: weather.isSafeToSail ? AppColors.safetyGreen : AppColors.crimsonAlert,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weather.advisory,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textWhite.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 24),

                  // Weather Grid details
                  Row(
                    children: [
                      // Wind Speed Knots
                      Expanded(
                        child: _buildWeatherMetricCard(
                          title: "WIND SPEED",
                          value: "${weather.windSpeedKnots.toStringAsFixed(1)} KTS",
                          subtitle: weather.windDirectionDescription,
                          icon: Icons.wind_power_rounded,
                          color: AppColors.skyBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Wave Height
                      Expanded(
                        child: _buildWeatherMetricCard(
                          title: "WAVE HEIGHT",
                          value: "${weather.waveHeightMeters.toStringAsFixed(1)} M",
                          subtitle: weather.waveHeightMeters > 1.8 ? "High swelling waves" : "Low Wave swell",
                          icon: Icons.waves_rounded,
                          color: AppColors.aquamarine,
                        ),
                      ),
                    ],
                  ).animate().slideY(begin: 0.1, delay: 200.ms),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Air Temperature
                      Expanded(
                        child: _buildWeatherMetricCard(
                          title: "TEMPERATURE",
                          value: "${weather.temperatureCelsius.toStringAsFixed(0)}° C",
                          subtitle: "Humidity: ${weather.humidityPercent}%",
                          icon: Icons.thermostat_rounded,
                          color: AppColors.warnings,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Barometric Pressure
                      Expanded(
                        child: _buildWeatherMetricCard(
                          title: "PRESSURE",
                          value: "${weather.pressureHpa.toStringAsFixed(0)} HPA",
                          subtitle: "Stable atmospheric",
                          icon: Icons.speed_rounded,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  ).animate().slideY(begin: 0.1, delay: 300.ms),

                  const SizedBox(height: 24),

                  // Tide Advisory Card
                  Card(
                    color: AppColors.cardNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.oceanNavy, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.watch_later_outlined, color: AppColors.aquamarine, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "TIDE SCHEDULES",
                                style: TextStyle(
                                  color: AppColors.sunlightHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildTideRow("High Tide", "04:32 AM", "1.4 M"),
                          const Divider(color: AppColors.oceanNavy, height: 16),
                          _buildTideRow("Low Tide", "10:56 AM", "0.2 M"),
                          const Divider(color: AppColors.oceanNavy, height: 16),
                          _buildTideRow("High Tide", "05:14 PM", "1.6 M"),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  if (weather.isFromApi) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Live weather data provided by Open-Meteo",
                        style: TextStyle(
                          color: AppColors.textMuted.withOpacity(0.6),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeatherMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.oceanNavy, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.sunlightHighContrast,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTideRow(String type, String time, String height) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          type,
          style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        Text(
          time,
          style: const TextStyle(color: AppColors.skyBlue, fontWeight: FontWeight.bold),
        ),
        Text(
          height,
          style: const TextStyle(color: AppColors.aquamarine, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
