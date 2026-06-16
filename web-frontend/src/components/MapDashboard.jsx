import React, { useEffect, useState, useRef } from 'react';
import L from 'leaflet';
import { syncManager } from '../services/syncManager';
import { voiceAssistant } from '../services/voiceAssistant';
import { translate } from '../services/localizations';
import { Settings, MessageSquare, AlertOctagon, CloudOff, Cloud, RefreshCw, Mic, MicOff, Navigation } from 'lucide-react';

// preconfigured International Boundary Line (IBL) polygon matching BorderAlertEngine.dart
const boundaryPolygon = [
  [9.00, 79.50],
  [9.20, 79.70],
  [9.30, 79.90],
  [9.50, 80.10],
  [9.70, 80.30],
  [9.80, 80.10],
  [9.50, 79.80],
  [9.20, 79.40]
];

// Ray-casting algorithm to determine if the point is inside the restricted boundary polygon
function isInsidePolygon(lat, lon) {
  let i, j = boundaryPolygon.length - 1;
  let oddNodes = false;
  for (i = 0; i < boundaryPolygon.length; i++) {
    const yi = boundaryPolygon[i][0];
    const xi = boundaryPolygon[i][1];
    const yj = boundaryPolygon[j][0];
    const xj = boundaryPolygon[j][1];

    if ((yi < lat && yj >= lat || yj < lat && yi >= lat) && (xi <= lon || xj <= lon)) {
      if (xi + (lat - yi) / (yj - yi) * (xj - xi) < lon) {
        oddNodes = !oddNodes;
      }
    }
    j = i;
  }
  return oddNodes;
}

// Calculates distance from a point to a line segment
function distanceToSegment(lat, lon, lat1, lon1, lat2, lon2) {
  const x = lon;
  const y = lat;
  const x1 = lon1;
  const y1 = lat1;
  const x2 = lon2;
  const y2 = lat2;

  const segmentLength = Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
  if (segmentLength === 0) return haversineDistance(lat, lon, lat1, lon1);

  const u = ((x - x1) * (x2 - x1) + (y - y1) * (y2 - y1)) / Math.pow(segmentLength, 2);

  if (u < 0.0) return haversineDistance(lat, lon, lat1, lon1);
  if (u > 1.0) return haversineDistance(lat, lon, lat2, lon2);

  const interLat = y1 + u * (y2 - y1);
  const interLon = x1 + u * (x2 - x1);
  return haversineDistance(lat, lon, interLat, interLon);
}

// Haversine Distance helper
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371.0; // Earth's radius in KM
  const dLat = (lat2 - lat1) * Math.PI / 180.0;
  const dLon = (lon2 - lon1) * Math.PI / 180.0;

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180.0) * Math.cos(lat2 * Math.PI / 180.0) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Calculates shortest distance to any edge of the boundary polygon
function getDistanceToBorder(lat, lon) {
  let minDistance = Infinity;
  for (let i = 0; i < boundaryPolygon.length; i++) {
    const p1 = boundaryPolygon[i];
    const p2 = boundaryPolygon[(i + 1) % boundaryPolygon.length];
    const distance = distanceToSegment(lat, lon, p1[0], p1[1], p2[0], p2[1]);
    if (distance < minDistance) {
      minDistance = distance;
    }
  }
  return minDistance;
}

export default function MapDashboard({
  currentPosition,
  setCurrentPosition,
  breadcrumbs,
  setBreadcrumbs,
  speedInKnots,
  setSpeedInKnots,
  heading,
  setHeading,
  onNavigate,
  currentLanguage
}) {
  // Expose geometry algorithms for Selenium E2E unit tests
  useEffect(() => {
    window.haversineDistance = haversineDistance;
    window.isInsidePolygon = isInsidePolygon;
    window.getDistanceToBorder = getDistanceToBorder;
  }, []);

  const mapContainerRef = useRef(null);
  const mapRef = useRef(null);
  const markerRef = useRef(null);
  const polygonRef = useRef(null);
  const polylineRef = useRef(null);

  const [isNearBorder, setIsNearBorder] = useState(false);
  const [distanceToBorder, setDistanceToBorder] = useState(0);
  const [syncState, setSyncState] = useState(syncManager.getState());
  const [voiceActive, setVoiceActive] = useState(false);
  const [voiceListening, setVoiceListening] = useState(false);

  // Autopilot simulation variables
  const [isSimulating, setIsSimulating] = useState(true);
  const simulationIntervalRef = useRef(null);

  // Subscribe to syncManager
  useEffect(() => {
    const unsubscribe = syncManager.subscribe((state) => {
      setSyncState(state);
    });
    return () => unsubscribe();
  }, []);

  // Initialize Leaflet Map
  useEffect(() => {
    if (!mapRef.current && mapContainerRef.current) {
      // Create map instance
      const map = L.map(mapContainerRef.current, {
        zoomControl: true,
        attributionControl: false
      }).setView([currentPosition.latitude, currentPosition.longitude], 12);
      mapRef.current = map;

      // OSM tile layer
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      }).addTo(map);

      // Plot restricted boundary
      const polygon = L.polygon(boundaryPolygon, {
        color: 'var(--crimson-alert)',
        fillColor: 'var(--crimson-alert)',
        fillOpacity: 0.18,
        weight: 3.0
      }).addTo(map);
      polygonRef.current = polygon;

      // Draw breadcrumbs
      const polyline = L.polyline(breadcrumbs.map(p => [p.latitude, p.longitude]), {
        color: 'var(--aquamarine)',
        weight: 4.5
      }).addTo(map);
      polylineRef.current = polyline;

      // Custom boat icon markup
      const boatIcon = L.divIcon({
        className: 'custom-boat-marker',
        html: `<div class="boat-aura"><div class="boat-core" style="transform: rotate(${heading}deg)"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg></div></div>`,
        iconSize: [45, 45],
        iconAnchor: [22.5, 22.5]
      });

      // Boat marker
      const marker = L.marker([currentPosition.latitude, currentPosition.longitude], {
        icon: boatIcon
      }).addTo(map);
      markerRef.current = marker;

      // Map click listener to teleport boat location
      map.on('click', (e) => {
        const { lat, lng } = e.latlng;
        setCurrentPosition({ latitude: lat, longitude: lng });
      });
    }

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Update map visual properties reactively
  useEffect(() => {
    const lat = currentPosition.latitude;
    const lon = currentPosition.longitude;

    // Boundary violation detection
    const inside = isInsidePolygon(lat, lon);
    const dist = getDistanceToBorder(lat, lon);

    // Border proximity warning threshold (e.g. within 2.5 km or inside)
    const near = inside || dist <= 2.5;
    
    if (near && !isNearBorder) {
      voiceAssistant.speak(
        `Warning! Approaching restricted maritime border. You are ${dist.toFixed(1)} kilometers from the boundary. Please turn back.`
      );
    }
    
    setIsNearBorder(near);
    setDistanceToBorder(dist);

    // Queue real-time location to sync service
    syncManager.queueGps(lat, lon, speedInKnots);

    // Update marker location & map center
    if (mapRef.current) {
      mapRef.current.setView([lat, lon], mapRef.current.getZoom());
    }

    if (markerRef.current) {
      markerRef.current.setLatLng([lat, lon]);
      // Update HTML inside divIcon to apply heading rotation dynamically
      const boatIcon = L.divIcon({
        className: 'custom-boat-marker',
        html: `<div class="boat-aura"><div class="boat-core" style="transform: rotate(${heading}deg)"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg></div></div>`,
        iconSize: [45, 45],
        iconAnchor: [22.5, 22.5]
      });
      markerRef.current.setIcon(boatIcon);
    }

    // Update breadcrumbs line
    if (polylineRef.current) {
      polylineRef.current.setLatLngs(breadcrumbs.map(p => [p.latitude, p.longitude]));
    }
  }, [currentPosition, heading]);

  // Voice assistant listener callback trigger
  const handleVoiceCommand = (words) => {
    if (words.includes('sos') || words.includes('help') || words.includes('emergency')) {
      onNavigate('sos');
    } else if (words.includes('weather') || words.includes('storm')) {
      onNavigate('weather');
    } else if (words.includes('chat') || words.includes('message')) {
      onNavigate('chat');
    } else if (words.includes('settings') || words.includes('profile')) {
      onNavigate('profile');
    }
  };

  const toggleVoice = () => {
    const active = voiceAssistant.toggleActive(
      handleVoiceCommand,
      (isListening) => setVoiceListening(isListening)
    );
    setVoiceActive(active);
  };

  // Simulating vessel location incremental drift
  useEffect(() => {
    if (isSimulating) {
      simulationIntervalRef.current = setInterval(() => {
        if (speedInKnots === 0) return;

        // Convert speed (knots) and heading (degrees) to coordinates drift
        // 1 Knot = 0.514 m/s. Let's scale standard movements per second
        const speedFactor = speedInKnots * 0.00002;
        const headingRad = (heading * Math.PI) / 180.0;
        
        const deltaLat = speedFactor * Math.cos(headingRad);
        const deltaLon = speedFactor * Math.sin(headingRad);

        setCurrentPosition((prev) => {
          const nextLat = prev.latitude + deltaLat;
          const nextLon = prev.longitude + deltaLon;
          const nextPos = { latitude: nextLat, longitude: nextLon };

          // Record path trail
          setBreadcrumbs((trail) => {
            const copy = [...trail, nextPos];
            if (copy.length > 50) copy.shift(); // keep last 50 points
            return copy;
          });

          return nextPos;
        });
      }, 1000);
    } else {
      if (simulationIntervalRef.current) {
        clearInterval(simulationIntervalRef.current);
      }
    }

    return () => {
      if (simulationIntervalRef.current) {
        clearInterval(simulationIntervalRef.current);
      }
    };
  }, [isSimulating, speedInKnots, heading]);

  return (
    <div style={styles.container}>
      {/* 1. Map Canvas wrapper */}
      <div ref={mapContainerRef} style={styles.mapCanvas} />

      {/* 2. Red Flashing boundary alert banner */}
      {isNearBorder && <div className="border-alert-flash" />}

      {/* 3. Voice Assistant FAB overlay */}
      <button
        id="voice-assistant-fab"
        onClick={toggleVoice}
        style={{
          ...styles.voiceFab,
          border: `2px solid ${
            voiceActive
              ? voiceListening
                ? 'var(--safety-green)'
                : 'var(--aquamarine)'
              : 'var(--ocean-blue)'
          }`,
          boxShadow: voiceActive
            ? `0 0 15px ${voiceListening ? 'var(--safety-green)' : 'var(--aquamarine)'}`
            : '0 4px 12px rgba(0,0,0,0.4)',
        }}
        title="Toggle Speech Assistant"
      >
        {voiceActive ? (
          <Mic size={24} color={voiceListening ? 'var(--safety-green)' : 'var(--text-white)'} />
        ) : (
          <MicOff size={24} color="var(--text-muted)" />
        )}
      </button>

      {/* 4. Top overlay panels (sync connection and active boundary alert banners) */}
      <div style={styles.topOverlayContainer}>
        {/* Border Warning alert */}
        {isNearBorder && (
          <div style={styles.borderBanner} className="gradient-alert-bg">
            <AlertOctagon size={24} color="#FFFFFF" />
            <div style={styles.bannerInfo}>
              <span style={styles.bannerTitle}>{translate('borderWarning', currentLanguage)}</span>
              <span style={styles.bannerSub}>
                {translate('borderDistance', currentLanguage)}{distanceToBorder.toFixed(2)} km
              </span>
            </div>
          </div>
        )}

        {/* Sync / Offline Connectivity Status banner */}
        <div
          style={{
            ...styles.syncBanner,
            backgroundColor: syncState.isOffline
              ? 'rgba(255, 183, 3, 0.95)'
              : 'rgba(10, 25, 47, 0.85)',
            border: `1.5px solid ${syncState.isOffline ? 'var(--warnings)' : 'var(--card-navy)'}`,
          }}
        >
          {syncState.isOffline ? (
            <CloudOff size={18} color="var(--text-white)" />
          ) : (
            <Cloud size={18} color="var(--aquamarine)" />
          )}
          <span style={styles.syncText}>
            {syncState.isOffline
              ? `${translate('offlineSync', currentLanguage)}${syncState.pendingGpsCount}`
              : "Secured Connection Active. Sync in real-time."}
          </span>
          {syncState.isOffline && (
            <button
              id="sync-refresh-btn"
              onClick={() => syncManager.setConnectionStatus(false)}
              style={styles.syncRefreshBtn}
            >
              <RefreshCw size={14} color="#FFFFFF" />
            </button>
          )}
        </div>
      </div>

      {/* 5. Simulating controls (interactive debugging panel) */}
      <div style={styles.debugCard}>
        <span style={styles.debugTitle}>VESSEL DRIFT SIMULATOR</span>
        <div style={styles.sliderRow}>
          <label style={styles.sliderLabel}>SPEED: {speedInKnots} KTS</label>
          <input
            id="simulator-speed-slider"
            type="range"
            min="0"
            max="30"
            value={speedInKnots}
            onChange={(e) => setSpeedInKnots(parseInt(e.target.value))}
            style={styles.slider}
          />
        </div>
        <div style={styles.sliderRow}>
          <label style={styles.sliderLabel}>HEADING: {heading}° N</label>
          <input
            id="simulator-heading-slider"
            type="range"
            min="0"
            max="359"
            value={heading}
            onChange={(e) => setHeading(parseInt(e.target.value))}
            style={styles.slider}
          />
        </div>
        <button
          id="simulator-autopilot-btn"
          onClick={() => setIsSimulating(!isSimulating)}
          style={{
            ...styles.simulateBtn,
            backgroundColor: isSimulating ? 'rgba(217, 4, 41, 0.12)' : 'rgba(46, 196, 182, 0.12)',
            border: `1px solid ${isSimulating ? 'var(--crimson-alert)' : 'var(--safety-green)'}`,
            color: isSimulating ? 'var(--crimson-alert)' : 'var(--safety-green)'
          }}
        >
          {isSimulating ? "PAUSE MOVEMENT" : "START DRIFT AUTOPILOT"}
        </button>
        <span style={styles.debugFoot}>Tip: Click anywhere on map to teleport vessel.</span>
      </div>

      {/* 6. Bottom Gauges HUD Overlay & Quick Actions */}
      <div style={styles.bottomOverlayContainer}>
        {/* HUD Gauges */}
        <div style={styles.gaugesRow}>
          <div style={styles.gaugeCard} className="glass-card">
            <span style={styles.gaugeLabel}>SPEED</span>
            <span id="gauge-speed-val" style={styles.gaugeVal}>{speedInKnots.toFixed(1)} <span style={styles.gaugeUnit}>KTS</span></span>
          </div>
          <div style={styles.gaugeCard} className="glass-card">
            <span style={styles.gaugeLabel}>HEADING</span>
            <span id="gauge-heading-val" style={styles.gaugeVal}>{heading.toFixed(0)}° <span style={styles.gaugeUnit}>N</span></span>
          </div>
        </div>

        {/* Action Panel */}
        <div style={styles.actionsBar}>
          <button id="nav-profile-btn" onClick={() => onNavigate('profile')} style={styles.actionFab} className="glass-card" title="Settings">
            <Settings size={22} color="var(--sky-blue)" />
          </button>
          
          <button id="nav-chat-btn" onClick={() => onNavigate('chat')} style={styles.actionFab} className="glass-card" title="Emergency Chat">
            <MessageSquare size={22} color="var(--sky-blue)" />
          </button>

          <button id="nav-sos-btn" onClick={() => onNavigate('sos')} style={styles.sosTriggerBtn}>
            <AlertOctagon size={24} />
            <span>SOS DISTRESS</span>
          </button>

          <button id="nav-weather-btn" onClick={() => onNavigate('weather')} style={styles.actionFab} className="glass-card" title="Marine Weather">
            <Cloud size={22} color="var(--sky-blue)" />
          </button>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    width: '100%',
    height: '100%',
    position: 'relative',
  },
  mapCanvas: {
    width: '100%',
    height: '100%',
    position: 'absolute',
    top: 0,
    left: 0,
  },
  voiceFab: {
    position: 'absolute',
    top: '60px',
    right: '16px',
    width: '54px',
    height: '54px',
    borderRadius: '50%',
    backgroundColor: 'var(--card-navy)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
    outline: 'none',
    zIndex: 500,
  },
  topOverlayContainer: {
    position: 'absolute',
    top: '20px',
    left: '16px',
    right: '16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    zIndex: 500,
  },
  borderBanner: {
    borderRadius: '16px',
    padding: '12px 16px',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    boxShadow: '0 8px 20px rgba(0,0,0,0.3)',
  },
  bannerInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  bannerTitle: {
    fontSize: '12px',
    fontWeight: '900',
    color: '#FFFFFF',
    letterSpacing: '0.5px',
  },
  bannerSub: {
    fontSize: '11px',
    color: 'rgba(255, 255, 255, 0.8)',
    fontWeight: '700',
  },
  syncBanner: {
    borderRadius: '12px',
    padding: '8px 14px',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
  },
  syncText: {
    fontSize: '11px',
    color: 'var(--text-white)',
    fontWeight: '700',
    flex: 1,
  },
  syncRefreshBtn: {
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
  },
  debugCard: {
    position: 'absolute',
    top: '130px',
    left: '16px',
    width: '200px',
    padding: '12px',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    zIndex: 500,
    fontSize: '11px',
  },
  debugTitle: {
    fontWeight: '900',
    color: 'var(--text-white)',
    borderBottom: '1px solid rgba(0, 119, 182, 0.15)',
    paddingBottom: '4px',
  },
  sliderRow: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  sliderLabel: {
    fontWeight: '700',
    color: 'var(--text-muted)',
    fontSize: '10px',
  },
  slider: {
    width: '100%',
    cursor: 'pointer',
  },
  simulateBtn: {
    fontSize: '9px',
    fontWeight: '800',
    padding: '6px',
    borderRadius: '6px',
    cursor: 'pointer',
  },
  debugFoot: {
    fontSize: '8px',
    color: 'var(--text-muted)',
    fontStyle: 'italic',
  },
  bottomOverlayContainer: {
    position: 'absolute',
    bottom: '24px',
    left: '16px',
    right: '16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
    zIndex: 500,
  },
  gaugesRow: {
    display: 'flex',
    gap: '12px',
  },
  gaugeCard: {
    flex: 1,
    padding: '12px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    background: 'rgba(17, 34, 64, 0.9) !important',
  },
  gaugeLabel: {
    fontSize: '9px',
    fontWeight: '800',
    color: 'var(--text-muted)',
    letterSpacing: '0.8px',
  },
  gaugeVal: {
    fontSize: '20px',
    fontWeight: '900',
    color: 'var(--aquamarine)',
    marginTop: '4px',
  },
  gaugeUnit: {
    fontSize: '10px',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
  actionsBar: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  actionFab: {
    width: '46px',
    height: '46px',
    borderRadius: '50%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
    border: 'none',
  },
  sosTriggerBtn: {
    flex: 1,
    height: '46px',
    borderRadius: '16px',
    backgroundColor: 'var(--crimson-alert)',
    color: '#FFFFFF',
    border: '1.5px solid #FFFFFF',
    boxShadow: '0 6px 16px rgba(217, 4, 41, 0.4)',
    cursor: 'pointer',
    fontWeight: '900',
    fontSize: '13px',
    letterSpacing: '0.5px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '8px',
  },
};
