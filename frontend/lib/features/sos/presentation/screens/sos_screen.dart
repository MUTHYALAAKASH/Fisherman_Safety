import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../map/services/location_service.dart';
import '../../../../services/sync_manager.dart';
import '../../../../shared/custom_button.dart';
import '../../../../services/voice_assistant_service.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsRemaining = 3;
  bool _isHolding = false;
  bool _isTriggered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startHolding() {
    setState(() {
      _isHolding = true;
      _secondsRemaining = 3;
    });

    HapticFeedback.vibrate();
    ref.read(voiceAssistantProvider.notifier).speak("S.O.S triggered. Hold for three seconds, or say cancel to abort.");

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
        HapticFeedback.heavyImpact();
        ref.read(voiceAssistantProvider.notifier).speak("$_secondsRemaining");
      } else {
        _triggerEmergency();
        timer.cancel();
      }
    });
  }

  void _stopHolding() {
    if (_isTriggered) return;
    _countdownTimer?.cancel();
    setState(() {
      _isHolding = false;
      _secondsRemaining = 3;
    });
    HapticFeedback.lightImpact();
    ref.read(voiceAssistantProvider.notifier).speak("Countdown cancelled.");
  }

  void _triggerEmergency() async {
    setState(() {
      _isHolding = false;
      _isTriggered = true;
    });

    HapticFeedback.vibrate();

    final location = ref.read(locationProvider).currentPosition;

    // Send to sync engine (will post immediately if online, else queue in Hive)
    final contacts = await ref.read(syncProvider.notifier).queueSos(
          location.latitude,
          location.longitude,
        );

    final names = contacts.map((c) => c['contactName'] ?? '').where((name) => name.toString().isNotEmpty).join(" and ");
    final voiceMsg = names.isNotEmpty
        ? "Emergency S.O.S activated. Sending distress alerts to $names and Coast Guard."
        : "Emergency S.O.S activated. Sending distress alerts to contacts and Coast Guard.";
    ref.read(voiceAssistantProvider.notifier).speak(voiceMsg);

    // Simulate direct offline local SMS dispatch
    _simulateSmsDispatch(location.latitude, location.longitude, contacts);
  }

  void _simulateSmsDispatch(double lat, double lon, List<dynamic> contacts) {
    debugPrint("🚨 [OFFLINE SMS GATEWAY] Dispatching emergency SOS coordinates to local SMS service...");
    for (var contact in contacts) {
      final name = contact['contactName'] ?? 'Family';
      final mobile = contact['contactMobile'] ?? '';
      debugPrint("SMS Payload to $name ($mobile): 'EMERGENCY SOS: Boat is in danger! Position: Lat $lat, Lon $lon. Please dispatch Search and Rescue immediately.'");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch voice assistant state
    final voiceState = ref.watch(voiceAssistantProvider);

    // Listen for cancel/stop voice command during emergency state
    ref.listen<VoiceState>(voiceAssistantProvider, (previous, next) {
      final words = next.lastWords.toLowerCase();
      if (words.contains('cancel') || words.contains('stop') || words.contains('abort') || words.contains('reset')) {
        if (_isHolding) {
          _stopHolding();
        } else if (_isTriggered) {
          setState(() {
            _isTriggered = false;
          });
          ref.read(voiceAssistantProvider.notifier).speak("Emergency SOS alarm reset.");
        }
      }
    });

    final syncState = ref.watch(syncProvider);
    final notifiedContacts = syncState.notifiedContacts;

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          AppLocalizations.translate('contacts').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          // Voice feedback active status indicator in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              voiceState.isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: voiceState.isActive
                  ? (voiceState.isListening ? AppColors.safetyGreen : AppColors.skyBlue)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Alert Banner
              if (_isTriggered)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.safetyGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.safetyGreen, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.safetyGreen, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.translate('sosTriggered'),
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: -0.2)
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.crimsonAlert.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.crimsonAlert.withOpacity(0.5), width: 1.5),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        "CRITICAL EMERGENCY SOS PORTAL",
                        style: TextStyle(
                          color: AppColors.crimsonAlert,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Triggering this portal will alert Coast Guard, family members, and nearby vessels immediately.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              const Spacer(),

              // Circular Pulse SOS Core Controls
              Center(
                child: GestureDetector(
                  onTapDown: (_) => _isTriggered ? null : _startHolding(),
                  onTapUp: (_) => _stopHolding(),
                  onTapCancel: () => _stopHolding(),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double scale = 1.0 + (_pulseController.value * 0.12);
                      if (_isHolding) scale = 1.25;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ripple
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isTriggered ? AppColors.safetyGreen : AppColors.crimsonAlert)
                                  .withOpacity(0.1),
                            ),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: false)).scale(begin: const Offset(0.8, 0.8), duration: 2.seconds, curve: Curves.easeOut),

                          // Mid Ripple
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isTriggered ? AppColors.safetyGreen : AppColors.crimsonAlert)
                                    .withOpacity(0.2),
                                border: Border.all(
                                  color: _isTriggered ? AppColors.safetyGreen : AppColors.crimsonAlert,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),

                          // Solid Core Button
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isTriggered ? AppColors.safetyGreen : AppColors.crimsonAlert,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isTriggered ? AppColors.safetyGreen : AppColors.crimsonAlert)
                                      .withOpacity(0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isTriggered ? Icons.check_rounded : Icons.sos_rounded,
                                    size: 52,
                                    color: Colors.white,
                                  ),
                                  if (_isHolding) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '$_secondsRemaining s',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Status Instruction Labels
              Center(
                child: Text(
                  _isTriggered
                      ? "EMERGENCY BROADCAST ACTIVE"
                      : _isHolding
                          ? AppLocalizations.translate('sosCountdown') + '$_secondsRemaining'
                          : AppLocalizations.translate('sosButton'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isTriggered
                        ? AppColors.safetyGreen
                        : _isHolding
                            ? AppColors.warnings
                            : AppColors.sunlightHighContrast,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
              ).animate().fadeIn(),

              const Spacer(),

              // Quick Cancel Instructions
              if (_isHolding)
                const Card(
                  color: AppColors.cardNavy,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.skyBlue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Release finger or say 'cancel' to abort",
                          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn()
              else ...[
                if (_isTriggered) ...[
                  // Premium Transmission Monitor Board (Dispatch monitor list only when active)
                  Card(
                    color: AppColors.cardNavy.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.oceanBlue, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.satellite_alt_rounded, color: AppColors.aquamarine, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "🚨 EMERGENCY DISPATCH MONITOR",
                                style: TextStyle(
                                  color: AppColors.sunlightHighContrast,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.oceanNavy, height: 24),
                          if (notifiedContacts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Initializing distress protocols...",
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            )
                          else
                            ...notifiedContacts.map((contact) {
                              final name = contact['contactName'] ?? 'Emergency Contact';
                              final mobile = contact['contactMobile'] ?? '';
                              final relation = contact['relationship'] ?? 'Family';
                              final isOffline = contact['deliveryStatus'] == 'SMS_QUEUED_OFFLINE';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$name ($relation)",
                                            style: const TextStyle(
                                              color: AppColors.textWhite,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            mobile,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isOffline
                                            ? AppColors.warnings.withOpacity(0.12)
                                            : AppColors.safetyGreen.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isOffline ? AppColors.warnings : AppColors.safetyGreen,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isOffline ? Icons.hourglass_top_rounded : Icons.done_all_rounded,
                                            color: isOffline ? AppColors.warnings : AppColors.safetyGreen,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOffline ? "QUEUED (OFFLINE)" : "SMS SENT",
                                            style: TextStyle(
                                              color: isOffline ? AppColors.warnings : AppColors.safetyGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 16),
                ],
                // VHF Radio Distress Signal (Always visible info panel)
                Card(
                  color: AppColors.cardNavy.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.oceanBlue, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "VHF Radio Distress Signal",
                              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              "Channel 16 (156.8 MHz)",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isTriggered ? AppColors.skyBlue.withOpacity(0.12) : AppColors.textMuted.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isTriggered ? AppColors.skyBlue : AppColors.textMuted, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isTriggered ? Icons.wifi_tethering_rounded : Icons.radio_rounded,
                                color: _isTriggered ? AppColors.skyBlue : AppColors.textMuted,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isTriggered ? "BROADCASTING" : "STANDBY",
                                style: TextStyle(
                                  color: _isTriggered ? AppColors.skyBlue : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(),
                if (_isTriggered) ...[
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Reset SOS Alarm",
                    color: AppColors.cardNavy,
                    onPressed: () {
                      setState(() {
                        _isTriggered = false;
                      });
                      ref.read(voiceAssistantProvider.notifier).speak("Emergency SOS alarm reset.");
                    },
                  ),
                ] else
                  const SizedBox(height: 56),
              ],

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
