import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceState {
  final bool isActive;       // Is voice assistant toggled ON
  final bool isListening;    // Is speech-to-text recording active
  final bool isSpeaking;     // Is text-to-speech speaking
  final String lastWords;    // Recognized text
  final String speechError;  // STT error message
  final bool isTtsSupported; // TTS capability status
  final bool isSttSupported; // STT capability status

  VoiceState({
    this.isActive = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.lastWords = '',
    this.speechError = '',
    this.isTtsSupported = false,
    this.isSttSupported = false,
  });

  VoiceState copyWith({
    bool? isActive,
    bool? isListening,
    bool? isSpeaking,
    String? lastWords,
    String? speechError,
    bool? isTtsSupported,
    bool? isSttSupported,
  }) {
    return VoiceState(
      isActive: isActive ?? this.isActive,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      lastWords: lastWords ?? this.lastWords,
      speechError: speechError ?? this.speechError,
      isTtsSupported: isTtsSupported ?? this.isTtsSupported,
      isSttSupported: isSttSupported ?? this.isSttSupported,
    );
  }
}

class VoiceAssistantService extends StateNotifier<VoiceState> {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _isSttInitialized = false;

  VoiceAssistantService() : super(VoiceState()) {
    _initTts();
    _initStt();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5); // Slower speech rate for marine clarity
      
      _tts.setStartHandler(() {
        state = state.copyWith(isSpeaking: true);
      });

      _tts.setCompletionHandler(() {
        state = state.copyWith(isSpeaking: false);
      });

      _tts.setErrorHandler((msg) {
        debugPrint("Voice TTS Error: $msg");
        state = state.copyWith(isSpeaking: false);
      });

      state = state.copyWith(isTtsSupported: true);
    } catch (e) {
      debugPrint("Failed to initialize TTS engine: $e");
    }
  }

  Future<void> _initStt() async {
    try {
      bool available = await _stt.initialize(
        onStatus: (status) {
          debugPrint("Voice STT Status: $status");
          if (status == 'listening') {
            state = state.copyWith(isListening: true);
          } else if (status == 'notListening' || status == 'done') {
            state = state.copyWith(isListening: false);
            // Auto restart listening if voice assistant is active globally
            if (state.isActive && !state.isSpeaking) {
              startListening();
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Voice STT Error: ${errorNotification.errorMsg}");
          state = state.copyWith(
            isListening: false,
            speechError: errorNotification.errorMsg,
          );
          // Auto restart listening on timeout errors if active
          if (state.isActive && errorNotification.errorMsg == 'error_speech_timeout') {
            startListening();
          }
        },
      );
      _isSttInitialized = available;
      state = state.copyWith(isSttSupported: available);
    } catch (e) {
      debugPrint("Failed to initialize STT engine: $e");
    }
  }

  // Speak out safety instructions or warnings (TTS)
  Future<void> speak(String text) async {
    if (!state.isTtsSupported) return;
    try {
      // Temporarily stop microphone listening to prevent feedback loops
      bool wasListening = state.isListening;
      if (wasListening) {
        await _stt.stop();
        state = state.copyWith(isListening: false);
      }
      
      await _tts.stop();
      await _tts.speak(text);
      
      // Resume listening once speech finishes (with a small delay buffer)
      if (wasListening && state.isActive) {
        Future.delayed(const Duration(seconds: 4), () {
          if (state.isActive && !state.isListening && !state.isSpeaking) {
            startListening();
          }
        });
      }
    } catch (e) {
      debugPrint("TTS speak failed: $e");
    }
  }

  // Toggle Voice Assistant on/off globally
  void toggleActive() {
    final newActive = !state.isActive;
    state = state.copyWith(isActive: newActive);
    if (newActive) {
      speak("Voice assistant activated. Listening for commands.");
      startListening();
    } else {
      speak("Voice assistant deactivated.");
      stopListening();
    }
  }

  // Start speech recording / command processing
  Future<void> startListening() async {
    if (!state.isActive) return;
    if (!_isSttInitialized) {
      await _initStt();
    }
    if (!state.isSttSupported) return;

    try {
      state = state.copyWith(speechError: '', lastWords: '');
      await _stt.listen(
        onResult: (result) {
          state = state.copyWith(lastWords: result.recognizedWords);
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint("STT listening session failed: $e");
    }
  }

  // Stop microphone listening
  Future<void> stopListening() async {
    try {
      await _stt.stop();
      state = state.copyWith(isListening: false);
    } catch (e) {
      debugPrint("STT stop failed: $e");
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }
}

final voiceAssistantProvider = StateNotifierProvider<VoiceAssistantService, VoiceState>((ref) {
  return VoiceAssistantService();
});
