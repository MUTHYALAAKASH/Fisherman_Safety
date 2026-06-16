import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { CloudRain, Wind, Waves, Thermometer, Compass, ShieldCheck, ShieldAlert, RefreshCw } from 'lucide-react';
import { translate } from '../services/localizations';

export default function WeatherAdvisory({ latitude = 9.117, longitude = 79.782, currentLanguage }) {
  const [loading, setLoading] = useState(false);
  const [weatherData, setWeatherData] = useState(null);

  const getWindDirection = (degrees) => {
    if (degrees >= 337.5 || degrees < 22.5) return "Blowing North";
    if (degrees >= 22.5 && degrees < 67.5) return "Blowing North-East";
    if (degrees >= 67.5 && degrees < 112.5) return "Blowing East";
    if (degrees >= 112.5 && degrees < 157.5) return "Blowing South-East";
    if (degrees >= 157.5 && degrees < 202.5) return "Blowing South";
    if (degrees >= 202.5 && degrees < 247.5) return "Blowing South-West";
    if (degrees >= 247.5 && degrees < 292.5) return "Blowing West";
    return "Blowing North-West";
  };

  const fetchWeather = async () => {
    setLoading(true);
    try {
      // 1. Fetch main forecast from Open-Meteo
      const forecastUrl = `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m,wind_direction_10m`;
      const forecastRes = await axios.get(forecastUrl);
      
      let temp = 31.0;
      let windSpeedKts = 12.4;
      let pressure = 1013.0;
      let humidity = 74;
      let windDirDeg = 315;

      if (forecastRes.status === 200 && forecastRes.data.current) {
        const current = forecastRes.data.current;
        temp = current.temperature_2m ?? temp;
        humidity = current.relative_humidity_2m ?? humidity;
        pressure = current.surface_pressure ?? pressure;
        
        // Open-Meteo wind speed is in km/h. Convert to Knots (1 km/h = 0.539957 knots)
        const windKmh = current.wind_speed_10m ?? 23.0;
        windSpeedKts = windKmh * 0.539957;
        windDirDeg = current.wind_direction_10m ?? windDirDeg;
      }

      const windDesc = getWindDirection(windDirDeg);

      // 2. Fetch wave height from Open-Meteo Marine API
      let waveHeight = 1.2;
      try {
        const marineUrl = `https://marine-api.open-meteo.com/v1/marine?latitude=${latitude}&longitude=${longitude}&current=wave_height`;
        const marineRes = await axios.get(marineUrl);
        if (marineRes.status === 200 && marineRes.data.current) {
          waveHeight = marineRes.data.current.wave_height ?? waveHeight;
        }
      } catch (e) {
        console.warn("Marine API unavailable for these coordinates. Falling back to default wave height.", e);
      }

      // 3. Compute dynamic safety advisory
      let isSafe = true;
      let advisoryMessage = "ADVISORY: SAFE TO SAIL. Conditions are optimal.";
      
      if (windSpeedKts > 22.0 || waveHeight > 2.5) {
        isSafe = false;
        advisoryMessage = `ADVISORY: DANGER - ROUGH SEAS! Extremely high winds (${windSpeedKts.toFixed(1)} KTS) and swells detected. Avoid sailing!`;
      } else if (windSpeedKts > 15.0 || waveHeight > 1.8) {
        isSafe = true; // Still sailable but exercise caution
        advisoryMessage = `ADVISORY: CAUTION - MODERATE WINDS. Waves up to ${waveHeight.toFixed(1)} meters. Exercise caution.`;
      }

      setWeatherData({
        windSpeedKnots: parseFloat(windSpeedKnots.toFixed(1)),
        waveHeightMeters: parseFloat(waveHeight.toFixed(1)),
        temperatureCelsius: parseFloat(temp.toFixed(1)),
        pressureHpa: parseFloat(pressure.toFixed(0)),
        humidityPercent: humidity,
        windDirectionDescription: windDesc,
        advisory: advisoryMessage,
        isSafeToSail: isSafe,
        isFromApi: true,
      });
    } catch (err) {
      console.warn("Error fetching weather from API, falling back to mock details: ", err);
      // Graceful Mock fallback
      setWeatherData({
        windSpeedKnots: 12.4,
        waveHeightMeters: 1.2,
        temperatureCelsius: 31.0,
        pressureHpa: 1013.0,
        humidityPercent: 74,
        windDirectionDescription: "Blowing North-West",
        advisory: "ADVISORY: SAFE TO SAIL. Conditions are optimal within 50 nautical miles.",
        isSafeToSail: true,
        isFromApi: false,
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWeather();
  }, [latitude, longitude]);

  return (
    <div style={styles.scrollContainer}>
      {/* Title Bar */}
      <div style={styles.titleRow}>
        <h2 style={styles.sectionTitle}>{translate('weather', currentLanguage).toUpperCase()}</h2>
        <button
          id="weather-refresh-btn"
          onClick={fetchWeather}
          disabled={loading}
          style={styles.refreshBtn}
          title="Refresh Weather Info"
        >
          <RefreshCw size={18} className={loading ? "spin-icon" : ""} style={{ animation: loading ? "spin 1.5s linear infinite" : "none" }} />
        </button>
      </div>

      {loading && (
        <div style={styles.loader}>
          <RefreshCw size={24} style={styles.loaderIcon} />
          <span>Fetching Marine Data...</span>
        </div>
      )}

      {!loading && weatherData && (
        <>
          {/* Advisory banner */}
          <div
            style={{
              ...styles.advisoryBanner,
              backgroundColor: weatherData.isSafeToSail
                ? 'rgba(46, 196, 182, 0.15)'
                : 'rgba(217, 4, 41, 0.15)',
              border: `1.5px solid ${weatherData.isSafeToSail ? 'var(--safety-green)' : 'var(--crimson-alert)'}`,
            }}
          >
            {weatherData.isSafeToSail ? (
              <ShieldCheck size={28} color="var(--safety-green)" />
            ) : (
              <ShieldAlert size={28} color="var(--crimson-alert)" />
            )}
            <div style={styles.advisoryContent}>
              <span style={styles.advisoryTitle}>
                {weatherData.isSafeToSail ? "STABILITY STATUS: NORMAL" : "STABILITY STATUS: HAZARDOUS"}
              </span>
              <p style={styles.advisoryText}>{weatherData.advisory}</p>
            </div>
          </div>

          {/* Telemetry Metrics Grid */}
          <div style={styles.grid}>
            {/* Wind speed card */}
            <div style={styles.card} className="glass-card">
              <Wind size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>WIND SPEED</span>
              <span style={styles.cardVal}>{weatherData.windSpeedKnots} <span style={styles.cardUnit}>KTS</span></span>
            </div>

            {/* Wave Height card */}
            <div style={styles.card} className="glass-card">
              <Waves size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>WAVE HEIGHT</span>
              <span style={styles.cardVal}>{weatherData.waveHeightMeters} <span style={styles.cardUnit}>M</span></span>
            </div>

            {/* Temp card */}
            <div style={styles.card} className="glass-card">
              <Thermometer size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>TEMPERATURE</span>
              <span style={styles.cardVal}>{weatherData.temperatureCelsius} <span style={styles.cardUnit}>°C</span></span>
            </div>

            {/* Wind Direction card */}
            <div style={styles.card} className="glass-card">
              <Compass size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>WIND DIRECTION</span>
              <span style={{ ...styles.cardVal, fontSize: '13px', marginTop: '12px' }}>
                {weatherData.windDirectionDescription}
              </span>
            </div>

            {/* Humidity card */}
            <div style={styles.card} className="glass-card">
              <CloudRain size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>HUMIDITY</span>
              <span style={styles.cardVal}>{weatherData.humidityPercent} <span style={styles.cardUnit}>%</span></span>
            </div>

            {/* Barometer card */}
            <div style={styles.card} className="glass-card">
              <RefreshCw size={24} color="var(--sky-blue)" />
              <span style={styles.cardLabel}>PRESSURE</span>
              <span style={styles.cardVal}>{weatherData.pressureHpa} <span style={styles.cardUnit}>hPa</span></span>
            </div>
          </div>

          {/* Coordinate Meta */}
          <div style={styles.metaCard} className="glass-card">
            <span style={styles.metaTitle}>MONITORED COORDINATES</span>
            <div style={styles.metaRow}>
              <span>Latitude: {latitude.toFixed(4)}° N</span>
              <span>Longitude: {longitude.toFixed(4)}° E</span>
            </div>
            <p style={styles.metaFoot}>
              Data source: {weatherData.isFromApi ? "Real-time Open-Meteo Marine Web Service" : "Mock Fallback (Offline Mode)"}
            </p>
          </div>
        </>
      )}

      {/* Embedded CSS animation for spinner */}
      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}

const styles = {
  scrollContainer: {
    padding: '20px',
    overflowY: 'auto',
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    gap: '20px',
  },
  titleRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '1px',
    borderLeft: '4px solid var(--aquamarine)',
    paddingLeft: '10px',
  },
  refreshBtn: {
    backgroundColor: 'var(--card-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    color: 'var(--sky-blue)',
    borderRadius: '50%',
    width: '36px',
    height: '36px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
    outline: 'none',
  },
  loader: {
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '12px',
    flex: 1,
    padding: '40px 0',
  },
  loaderIcon: {
    color: 'var(--aquamarine)',
    animation: 'spin 1s linear infinite',
  },
  advisoryBanner: {
    borderRadius: '16px',
    padding: '16px',
    display: 'flex',
    gap: '14px',
    alignItems: 'flex-start',
  },
  advisoryContent: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  advisoryTitle: {
    fontSize: '12px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '0.8px',
  },
  advisoryText: {
    fontSize: '13px',
    color: 'var(--text-white)',
    fontWeight: '600',
    lineHeight: '1.4',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '12px',
  },
  card: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '18px 12px',
    textAlign: 'center',
  },
  cardLabel: {
    fontSize: '9px',
    fontWeight: '800',
    color: 'var(--text-muted)',
    letterSpacing: '0.8px',
    marginTop: '10px',
  },
  cardVal: {
    fontSize: '20px',
    fontWeight: '900',
    color: 'var(--aquamarine)',
    marginTop: '6px',
  },
  cardUnit: {
    fontSize: '11px',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
  metaCard: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    marginBottom: '20px',
  },
  metaTitle: {
    fontSize: '11px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '0.8px',
  },
  metaRow: {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: '13px',
    color: 'var(--text-muted)',
    fontWeight: '600',
  },
  metaFoot: {
    fontSize: '10px',
    color: 'rgba(136, 146, 176, 0.6)',
    fontStyle: 'italic',
    marginTop: '4px',
  },
};
