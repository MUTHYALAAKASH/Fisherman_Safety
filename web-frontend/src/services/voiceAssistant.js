// Browser-native Web Speech API wrapper for Voice Assistant features
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

class VoiceAssistantService {
  constructor() {
    this.recognition = null;
    this.active = false;
    this.listening = false;
    this.onResultCallback = null;
    this.onListeningChangeCallback = null;

    if (SpeechRecognition) {
      this.recognition = new SpeechRecognition();
      this.recognition.continuous = true;
      this.recognition.interimResults = false;
      this.recognition.lang = 'en-US';

      this.recognition.onstart = () => {
        this.listening = true;
        if (this.onListeningChangeCallback) {
          this.onListeningChangeCallback(true);
        }
      };

      this.recognition.onend = () => {
        this.listening = false;
        if (this.onListeningChangeCallback) {
          this.onListeningChangeCallback(false);
        }
        // Auto-restart if it was set active and stopped by browser timeout
        if (this.active) {
          try {
            this.recognition.start();
          } catch (e) {
            console.error("Auto-restart voice recognition failed:", e);
          }
        }
      };

      this.recognition.onresult = (event) => {
        const lastResultIndex = event.results.length - 1;
        const transcript = event.results[lastResultIndex][0].transcript.trim().toLowerCase();
        console.log("🗣️ Voice Input: ", transcript);

        if (this.onResultCallback) {
          this.onResultCallback(transcript);
        }
      };

      this.recognition.onerror = (event) => {
        console.error("Voice recognition error: ", event.error);
        if (event.error === 'not-allowed') {
          this.active = false;
          if (this.onListeningChangeCallback) {
            this.onListeningChangeCallback(false);
          }
        }
      };
    } else {
      console.warn("Web Speech API (SpeechRecognition) is not supported in this browser.");
    }
  }

  toggleActive(onResult, onListeningChange) {
    if (!this.recognition) return false;

    this.onResultCallback = onResult;
    this.onListeningChangeCallback = onListeningChange;

    if (this.active) {
      this.active = false;
      this.recognition.stop();
      this.speak("Voice assistant deactivated.");
    } else {
      this.active = true;
      try {
        this.recognition.start();
        this.speak("Voice assistant active.");
      } catch (e) {
        console.error("Start voice recognition failed:", e);
      }
    }
    return this.active;
  }

  stop() {
    this.active = false;
    if (this.recognition) {
      this.recognition.stop();
    }
  }

  speak(text) {
    if ('speechSynthesis' in window) {
      // Cancel previous speech to avoid queue pile-up
      window.speechSynthesis.cancel();
      const utterance = new SpeechUtterance(text);
      utterance.rate = 1.0;
      utterance.pitch = 1.0;
      window.speechSynthesis.speak(utterance);
      console.log("🔊 Speak: ", text);
    }
  }
}

export const voiceAssistant = new VoiceAssistantService();
