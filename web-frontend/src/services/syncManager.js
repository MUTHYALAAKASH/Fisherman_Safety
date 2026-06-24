import axios from 'axios';

const API_BASE_URL = 'http://localhost:8080';

// Axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

// Request interceptor to dynamically inject the JWT bearer token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('jwt_token');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor to cache successfully fetched emergency contacts
api.interceptors.response.use(
  (response) => {
    if (response.config.url === '/api/users/contacts' && response.status === 200) {
      localStorage.setItem('emergency_contacts', JSON.stringify(response.data));
    }
    return response;
  },
  (error) => Promise.reject(error)
);

class SyncManagerService {
  constructor() {
    this.isOffline = !navigator.onLine;
    this.notifiedContacts = [];
    this.listeners = [];

    // Initialize local storage keys if empty
    if (!localStorage.getItem('gps_box')) {
      localStorage.setItem('gps_box', JSON.stringify([]));
    }
    if (!localStorage.getItem('sos_box')) {
      localStorage.setItem('sos_box', JSON.stringify([]));
    }

    // Auto-listen to window network connectivity events
    window.addEventListener('online', () => this.setConnectionStatus(false));
    window.addEventListener('offline', () => this.setConnectionStatus(true));
  }

  subscribe(listener) {
    this.listeners.push(listener);
    // Initial call
    listener(this.getState());
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }

  notify() {
    const state = this.getState();
    this.listeners.forEach((listener) => listener(state));
  }

  getState() {
    const gpsBox = JSON.parse(localStorage.getItem('gps_box') || '[]');
    const sosBox = JSON.parse(localStorage.getItem('sos_box') || '[]');
    return {
      isOffline: this.isOffline,
      pendingGpsCount: gpsBox.length,
      pendingSosCount: sosBox.length,
      notifiedContacts: this.notifiedContacts,
    };
  }

  setConnectionStatus(isOffline) {
    this.isOffline = isOffline;
    this.notify();
    if (!isOffline) {
      this.triggerSync();
    }
  }

  // Queue tracking packet locally or send directly
  async queueGps(latitude, longitude, speed) {
    const timestamp = new Date().toISOString();
    const payload = { latitude, longitude, speed, timestamp };

    if (this.isOffline) {
      const gpsBox = JSON.parse(localStorage.getItem('gps_box') || '[]');
      gpsBox.push(payload);
      localStorage.setItem('gps_box', JSON.stringify(gpsBox));
      this.notify();
      console.log("Offline: Telemetry packet queued locally in gps_box.");
    } else {
      try {
        await api.post('/api/gps/update', payload);
        console.log("Online: Telemetry packet pushed directly to server.");
      } catch (e) {
        console.error("Online push failed, queueing telemetry offline:", e);
        this.isOffline = true;
        await this.queueGps(latitude, longitude, speed);
      }
    }
  }

  // Queue SOS alert locally or send directly
  async queueSos(latitude, longitude) {
    const payload = { latitude, longitude };

    if (this.isOffline) {
      const sosBox = JSON.parse(localStorage.getItem('sos_box') || '[]');
      sosBox.push(payload);
      localStorage.setItem('sos_box', JSON.stringify(sosBox));

      let cachedContacts = null;
      try {
        const stored = localStorage.getItem('emergency_contacts');
        if (stored !== null) {
          cachedContacts = JSON.parse(stored);
        }
      } catch (err) {
        console.error("Error reading cached contacts: ", err);
      }

      const offlineContacts = cachedContacts !== null
        ? cachedContacts.map(c => ({
            contactName: c.contactName,
            contactMobile: c.contactMobile,
            relationship: c.relationship,
            deliveryStatus: 'SMS_QUEUED_OFFLINE'
          }))
        : [
            { contactName: 'Arul Kumar', contactMobile: '9876543210', relationship: 'Brother', deliveryStatus: 'SMS_QUEUED_OFFLINE' },
            { contactName: 'Kavita Raja', contactMobile: '9080706050', relationship: 'Wife', deliveryStatus: 'SMS_QUEUED_OFFLINE' }
          ];

      this.notifiedContacts = offlineContacts;
      this.notify();
      console.log("Offline: Critical SOS queued locally in sos_box.");
      return offlineContacts;
    } else {
      try {
        const response = await api.post('/api/sos/trigger', payload);
        const contacts = response.data.notifiedContacts || [];
        this.notifiedContacts = contacts;
        this.notify();
        console.log("Online: SOS broadcast triggered.");
        return contacts;
      } catch (e) {
        console.error("Online SOS broadcast failed, caching SOS offline:", e);
        this.isOffline = true;
        return await this.queueSos(latitude, longitude);
      }
    }
  }

  // Bulk flush local queues
  async triggerSync() {
    if (this.isOffline) return;

    const sosBox = JSON.parse(localStorage.getItem('sos_box') || '[]');
    const gpsBox = JSON.parse(localStorage.getItem('gps_box') || '[]');

    if (sosBox.length === 0 && gpsBox.length === 0) return;
    console.log("🔄 Sync Engine triggered. Flushing local buffers online...");

    // 1. Sync SOS alerts first (highest priority)
    while (sosBox.length > 0) {
      const data = sosBox[0];
      try {
        await api.post('/api/sos/trigger', {
          latitude: data.latitude,
          longitude: data.longitude,
        });
        sosBox.shift();
        localStorage.setItem('sos_box', JSON.stringify(sosBox));
        this.notify();
      } catch (e) {
        console.error("Failed to sync SOS element: ", e);
        this.setConnectionStatus(true);
        return;
      }
    }

    // 2. Sync GPS Telemetry
    while (gpsBox.length > 0) {
      const data = gpsBox[0];
      try {
        await api.post('/api/gps/update', {
          latitude: data.latitude,
          longitude: data.longitude,
          speed: data.speed,
          timestamp: data.timestamp,
        });
        gpsBox.shift();
        localStorage.setItem('gps_box', JSON.stringify(gpsBox));
        this.notify();
      } catch (e) {
        console.error("Failed to sync GPS element: ", e);
        this.setConnectionStatus(true);
        return;
      }
    }

    console.log("✅ Caches cleared and synchronized successfully.");
  }
}

export const syncManager = new SyncManagerService();
export { api };
export { API_BASE_URL };
