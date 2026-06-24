import React, { useState, useEffect } from 'react';
import LoginRegister from './components/LoginRegister';
import MapDashboard from './components/MapDashboard';
import SosPortal from './components/SosPortal';
import Chat from './components/Chat';
import WeatherAdvisory from './components/WeatherAdvisory';
import ProfileSettings from './components/ProfileSettings';
import { translate } from './services/localizations';
import { voiceAssistant } from './services/voiceAssistant';
import { syncManager } from './services/syncManager';
import {
  Navigation,
  Cloud,
  MessageSquare,
  AlertTriangle,
  User,
  LogOut,
  Menu,
  X,
  Radio,
  CloudOff
} from 'lucide-react';

export default function App() {
  const [userProfile, setUserProfile] = useState(() => {
    const saved = localStorage.getItem('user_profile');
    return saved ? JSON.parse(saved) : null;
  });

  const [currentLanguage, setCurrentLanguage] = useState(() => {
    return localStorage.getItem('app_lang') || 'en';
  });

  // Navigation states: 'dashboard' (Map), 'weather', 'chat', 'sos', 'profile'
  const [currentView, setCurrentView] = useState('dashboard');
  
  // Mobile drawer state
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // Vessel Position state: defaults to Palk Strait region
  const [currentPosition, setCurrentPosition] = useState({
    latitude: 9.117,
    longitude: 79.782
  });

  const [breadcrumbs, setBreadcrumbs] = useState([
    { latitude: 9.110, longitude: 79.775 },
    { latitude: 9.113, longitude: 79.779 },
    { latitude: 9.117, longitude: 79.782 }
  ]);

  const [speedInKnots, setSpeedInKnots] = useState(12);
  const [heading, setHeading] = useState(45);
  const [syncState, setSyncState] = useState(syncManager.getState());

  useEffect(() => {
    const unsubscribe = syncManager.subscribe((state) => {
      setSyncState(state);
    });
    return () => unsubscribe();
  }, []);

  // Query actual browser location on startup to customize coordinates & weather
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const lat = position.coords.latitude;
          const lon = position.coords.longitude;
          setCurrentPosition({ latitude: lat, longitude: lon });
          setBreadcrumbs([
            { latitude: lat - 0.002, longitude: lon - 0.002 },
            { latitude: lat - 0.001, longitude: lon - 0.001 },
            { latitude: lat, longitude: lon }
          ]);
        },
        (error) => {
          console.warn("Browser Geolocation access error or denied, using defaults: ", error);
        },
        { enableHighAccuracy: true, timeout: 8000 }
      );
    }
  }, []);

  const handleAuthSuccess = (profile) => {
    setUserProfile(profile);
    setCurrentView('dashboard');
  };

  const handleLogout = () => {
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('user_profile');
    setUserProfile(null);
    voiceAssistant.stop();
  };

  const handleLanguageChange = (langCode) => {
    setCurrentLanguage(langCode);
    localStorage.setItem('app_lang', langCode);
  };

  const handleProfileUpdate = (profile) => {
    setUserProfile(profile);
  };

  // Synchronize dynamic offline queue on startup
  useEffect(() => {
    syncManager.triggerSync();
    window.translate = translate;
  }, []);

  if (!userProfile) {
    return (
      <div style={styles.loginPage}>
        <LoginRegister
          onAuthSuccess={handleAuthSuccess}
          currentLanguage={currentLanguage}
        />
      </div>
    );
  }

  const navItems = [
    { id: 'dashboard', label: translate('map', currentLanguage), icon: <Navigation size={18} /> },
    { id: 'weather', label: translate('weather', currentLanguage), icon: <Cloud size={18} /> },
    { id: 'chat', label: translate('contacts', currentLanguage), icon: <MessageSquare size={18} /> },
    { id: 'sos', label: 'SOS Emergency', icon: <AlertTriangle size={18} /> },
    { id: 'profile', label: translate('profile', currentLanguage), icon: <User size={18} /> },
  ];

  return (
    <div className="app-container">
      {/* 1. SIDEBAR PANEL (Drawer on Mobile, Fixed Sidebar on Desktop) */}
      <div className={`sidebar ${sidebarOpen ? 'open' : ''}`} style={styles.sidebarCustom}>
        {/* Brand Banner */}
        <div style={styles.brand}>
          <div style={styles.iconContainer}>
            <Navigation size={22} color="var(--aquamarine)" style={{ transform: 'rotate(45deg)' }} />
          </div>
          <div>
            <h1 style={styles.brandTitle}>MARITIME COMMAND</h1>
            <p style={styles.brandSub}>SAFETY MONITORS HUD</p>
          </div>
          <button onClick={() => setSidebarOpen(false)} style={styles.sidebarCloseBtn}>
            <X size={20} />
          </button>
        </div>

        {/* Navigation List */}
        <nav style={styles.nav}>
          {navItems.map((item) => {
            const isActive = currentView === item.id;
            return (
              <button
                id={`sidebar-nav-${item.id}`}
                key={item.id}
                onClick={() => {
                  setCurrentView(item.id);
                  setSidebarOpen(false);
                }}
                style={{
                  ...styles.navItem,
                  backgroundColor: isActive ? 'rgba(0, 180, 216, 0.15)' : 'transparent',
                  borderLeft: `3px solid ${isActive ? 'var(--aquamarine)' : 'transparent'}`,
                  color: isActive ? 'var(--aquamarine)' : 'var(--text-muted)'
                }}
              >
                {item.icon}
                <span style={styles.navLabel}>{item.label}</span>
              </button>
            );
          })}
        </nav>

        {/* Sync Status Banner */}
        <div
          style={{
            ...styles.sidebarSyncCard,
            backgroundColor: syncState.isOffline ? 'rgba(255, 183, 3, 0.1)' : 'rgba(3, 12, 27, 0.4)',
            border: `1px solid ${syncState.isOffline ? 'var(--warnings)' : 'rgba(0, 119, 182, 0.15)'}`
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Radio size={14} color={syncState.isOffline ? 'var(--warnings)' : 'var(--safety-green)'} />
            <span style={{ fontSize: '11px', fontWeight: 'bold' }}>
              {syncState.isOffline ? 'OFFLINE CACHE' : 'SECURED CLIENT'}
            </span>
          </div>
          {syncState.isOffline && (
            <p style={styles.syncCardSub}>
              {translate('offlineSync', currentLanguage)}{syncState.pendingGpsCount} packets
            </p>
          )}
        </div>

        {/* Profile Card & Logout */}
        <div style={styles.profileCard}>
          <div style={styles.profileInfo}>
            <User size={18} color="var(--sky-blue)" />
            <div style={styles.profileMeta}>
              <span style={styles.profileName}>{userProfile.fullName}</span>
              <span style={styles.profileSub}>
                {userProfile.boatName ? `${userProfile.boatName}` : 'Vessel Operator'}
              </span>
            </div>
          </div>
          <button id="sidebar-logout-btn" onClick={handleLogout} style={styles.logoutBtn} title="Sign Out">
            <LogOut size={16} />
          </button>
        </div>
      </div>

      {/* 2. MAIN HUB CONTENT VIEWPORT */}
      <div className="main-content">
        {/* Mobile Header Bar */}
        <header style={styles.mobileHeader}>
          <button onClick={() => setSidebarOpen(true)} style={styles.menuBtn}>
            <Menu size={24} />
          </button>
          <span style={styles.mobileTitle}>{translate('appTitle', currentLanguage)}</span>
        </header>

        {/* Active Screen views */}
        {currentView === 'dashboard' && (
          <MapDashboard
            currentPosition={currentPosition}
            setCurrentPosition={setCurrentPosition}
            breadcrumbs={breadcrumbs}
            setBreadcrumbs={setBreadcrumbs}
            speedInKnots={speedInKnots}
            setSpeedInKnots={setSpeedInKnots}
            heading={heading}
            setHeading={setHeading}
            currentLanguage={currentLanguage}
            onNavigate={(view) => setCurrentView(view)}
          />
        )}

        {currentView !== 'dashboard' && (
          <div style={styles.contentScrollWrapper}>
            {currentView === 'sos' && (
              <SosPortal
                currentPosition={currentPosition}
                currentLanguage={currentLanguage}
              />
            )}

            {currentView === 'chat' && (
              <Chat
                currentPosition={currentPosition}
                userProfile={userProfile}
                currentLanguage={currentLanguage}
              />
            )}

            {currentView === 'weather' && (
              <WeatherAdvisory
                latitude={currentPosition.latitude}
                longitude={currentPosition.longitude}
                currentLanguage={currentLanguage}
              />
            )}

            {currentView === 'profile' && (
              <ProfileSettings
                userProfile={userProfile}
                onProfileUpdate={handleProfileUpdate}
                onLogout={handleLogout}
                currentLanguage={currentLanguage}
                onLanguageChange={handleLanguageChange}
              />
            )}
          </div>
        )}
      </div>
    </div>
  );
}

const styles = {
  loginPage: {
    width: '100vw',
    height: '100vh',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    background: 'linear-gradient(to bottom, var(--deep-navy), var(--ocean-navy))',
  },
  sidebarCustom: {
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    borderBottom: '1px solid rgba(0, 119, 182, 0.15)',
    paddingBottom: '16px',
    position: 'relative',
  },
  iconContainer: {
    width: '40px',
    height: '40px',
    borderRadius: '10px',
    backgroundColor: 'rgba(0, 245, 212, 0.1)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    border: '1.5px solid var(--aquamarine)',
  },
  brandTitle: {
    fontSize: '13px',
    fontWeight: '950',
    color: 'var(--text-white)',
    letterSpacing: '1px',
  },
  brandSub: {
    fontSize: '9px',
    fontWeight: '700',
    color: 'var(--text-muted)',
    letterSpacing: '1.5px',
    marginTop: '2px',
  },
  sidebarCloseBtn: {
    display: 'none',
    position: 'absolute',
    right: '0',
    top: '8px',
    background: 'none',
    border: 'none',
    color: 'var(--text-white)',
    cursor: 'pointer',
    '@media (max-width: 768px)': {
      display: 'block',
    },
  },
  nav: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    flex: 1,
  },
  navItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '14px',
    padding: '12px 14px',
    borderRadius: '10px',
    border: 'none',
    cursor: 'pointer',
    textAlign: 'left',
    width: '100%',
    fontWeight: '700',
    fontSize: '13px',
    transition: 'background-color 0.2s',
  },
  navLabel: {
    letterSpacing: '0.5px',
  },
  sidebarSyncCard: {
    borderRadius: '12px',
    padding: '12px',
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  syncCardSub: {
    fontSize: '10px',
    color: 'var(--text-muted)',
  },
  profileCard: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px',
    backgroundColor: 'var(--deep-navy)',
    borderRadius: '12px',
    border: '1px solid rgba(0, 119, 182, 0.1)',
  },
  profileInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
  },
  profileMeta: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  profileName: {
    fontSize: '12px',
    fontWeight: '800',
    color: 'var(--text-white)',
  },
  profileSub: {
    fontSize: '10px',
    color: 'var(--text-muted)',
  },
  logoutBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--crimson-alert)',
    cursor: 'pointer',
    padding: '4px',
    display: 'flex',
    alignItems: 'center',
  },
  mobileHeader: {
    height: '60px',
    backgroundColor: 'var(--card-navy)',
    borderBottom: '1.5px solid rgba(0, 119, 182, 0.25)',
    display: 'none',
    alignItems: 'center',
    padding: '0 16px',
    gap: '16px',
    zIndex: 900,
    flexShrink: 0,
  },
  menuBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--text-white)',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
  },
  mobileTitle: {
    fontSize: '14px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '0.5px',
  },
  contentScrollWrapper: {
    flex: 1,
    overflowY: 'auto',
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: 'var(--deep-navy)',
  },
};

// Add raw CSS rule to overlay sidebarCloseBtn display on media queries
const styleTag = document.createElement('style');
styleTag.innerHTML = `
  @media (max-width: 768px) {
    .sidebar button[style*="sidebarCloseBtn"] {
      display: block !important;
    }
    header[style*="mobileHeader"] {
      display: flex !important;
    }
  }
`;
document.head.appendChild(styleTag);
