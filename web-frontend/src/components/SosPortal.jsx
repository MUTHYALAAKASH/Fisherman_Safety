import React, { useState, useEffect, useRef } from 'react';
import { syncManager } from '../services/syncManager';
import { voiceAssistant } from '../services/voiceAssistant';
import { Radio, AlertTriangle, ShieldCheck, Activity } from 'lucide-react';
import { translate } from '../services/localizations';

export default function SosPortal({ currentPosition, currentLanguage }) {
  const [secondsRemaining, setSecondsRemaining] = useState(3);
  const [isHolding, setIsHolding] = useState(false);
  const [isTriggered, setIsTriggered] = useState(false);
  const [notifiedContacts, setNotifiedContacts] = useState([]);
  const [syncState, setSyncState] = useState(syncManager.getState());

  const countdownTimerRef = useRef(null);

  // Subscribe to syncManager state
  useEffect(() => {
    const unsubscribe = syncManager.subscribe((state) => {
      setSyncState(state);
      if (isTriggered) {
        setNotifiedContacts(state.notifiedContacts);
      }
    });
    return () => unsubscribe();
  }, [isTriggered]);

  const startHolding = () => {
    if (isTriggered) return;
    setIsHolding(true);
    setSecondsRemaining(3);
    voiceAssistant.speak("S.O.S triggered. Hold for three seconds to activate distress broadcast.");

    let secs = 3;
    countdownTimerRef.current = setInterval(() => {
      if (secs > 1) {
        secs--;
        setSecondsRemaining(secs);
        voiceAssistant.speak(secs.toString());
      } else {
        triggerEmergency();
        cleanup();
      }
    }, 1000);

    const cleanup = () => {
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
      setIsHolding(false);
      window.removeEventListener('mouseup', handleGlobalMouseUp);
      window.removeEventListener('touchend', handleGlobalTouchEnd);
    };

    const handleGlobalMouseUp = () => {
      if (!isTriggered) {
        voiceAssistant.speak("distress alarm cancelled.");
      }
      cleanup();
    };

    const handleGlobalTouchEnd = () => {
      if (!isTriggered) {
        voiceAssistant.speak("distress alarm cancelled.");
      }
      cleanup();
    };

    window.addEventListener('mouseup', handleGlobalMouseUp);
    window.addEventListener('touchend', handleGlobalTouchEnd);
  };

  const triggerEmergency = async () => {
    setIsHolding(false);
    setIsTriggered(true);
    voiceAssistant.speak("Emergency S.O.S activated. Sending distress alerts with GPS coordinates to contacts and Coast Guard.");

    const contacts = await syncManager.queueSos(
      currentPosition.latitude,
      currentPosition.longitude
    );
    setNotifiedContacts(contacts);
  };

  const resetAlarm = () => {
    setIsTriggered(false);
    setNotifiedContacts([]);
    voiceAssistant.speak("Emergency S.O.S alarm has been reset.");
  };

  return (
    <div style={styles.scrollContainer} className="sos-scroll-container">
      {/* AppBar title */}
      <h2 style={styles.sectionTitle}>{translate('contacts', currentLanguage).toUpperCase()}</h2>

      {/* Top Advisory Card */}
      {isTriggered ? (
        <div style={{ ...styles.topBanner, ...styles.topBannerActive }} className="gradient-safe-bg">
          <ShieldCheck size={28} />
          <div>
            <span style={styles.bannerTitle}>{translate('sosTriggered', currentLanguage)}</span>
            <p style={styles.bannerText}>Distress broadcast is active. Emergency Coast Guard crews are tracking your location.</p>
          </div>
        </div>
      ) : (
        <div style={styles.topBanner} className="glass-card">
          <AlertTriangle size={28} color="var(--crimson-alert)" />
          <div style={styles.bannerContent}>
            <span style={{ ...styles.bannerTitle, color: 'var(--crimson-alert)' }}>CRITICAL EMERGENCY SOS PORTAL</span>
            <p style={styles.bannerText}>Hold down the circular button for 3 seconds to broadcast coordinates immediately.</p>
          </div>
        </div>
      )}

      {/* Split Layout Container */}
      <div className="sos-split-layout">
        {/* Left Side: SOS Button Core */}
        <div className="sos-left-panel">
          <div style={styles.btnSection}>
            <div
              id="sos-circular-btn"
              onMouseDown={startHolding}
              onTouchStart={(e) => { e.preventDefault(); startHolding(); }}
              style={{
                ...styles.sosButton,
                backgroundColor: isTriggered ? 'var(--safety-green)' : 'var(--crimson-alert)',
                boxShadow: `0 8px 32px ${isTriggered ? 'rgba(46, 196, 182, 0.4)' : 'rgba(217, 4, 41, 0.4)'}`,
                cursor: isTriggered ? 'default' : 'pointer',
              }}
            >
              {isHolding && <div className="sos-ripple" />}
              {isTriggered && <div className="sos-ripple-safe" />}

              <div style={styles.innerCore}>
                {isTriggered ? (
                  <ShieldCheck size={52} color="var(--text-white)" />
                ) : (
                  <AlertTriangle size={52} color="var(--text-white)" />
                )}
                {isHolding && (
                  <span style={styles.countdownText}>{secondsRemaining}s</span>
                )}
              </div>
            </div>
          </div>

          <div style={styles.statusLabelContainer}>
            <span
              style={{
                ...styles.statusLabel,
                color: isTriggered
                  ? 'var(--safety-green)'
                  : isHolding
                  ? 'var(--warnings)'
                  : 'var(--text-white)',
              }}
            >
              {isTriggered
                ? "EMERGENCY BROADCAST ACTIVE"
                : isHolding
                ? `${translate('sosCountdown', currentLanguage)}${secondsRemaining}s`
                : translate('sosButton', currentLanguage)}
            </span>
            {isHolding && (
              <p style={styles.cancelFoot}>Release finger to abort</p>
            )}
          </div>
        </div>

        {/* Right Side: Monitors & Dispatch */}
        <div className="sos-right-panel">
          {/* Emergency dispatch monitor */}
          {isTriggered && (
            <div style={styles.monitorCard} className="glass-card">
              <h3 style={styles.monitorTitle}>
                <Activity size={18} color="var(--aquamarine)" />
                <span>🚨 EMERGENCY DISPATCH MONITOR</span>
              </h3>
              <div style={styles.divider} />
              {notifiedContacts.length === 0 ? (
                <p style={styles.monitorLoading}>Initializing distress protocols...</p>
              ) : (
                <div style={styles.contactList}>
                  {notifiedContacts.map((contact, index) => {
                    const isQueued = contact.deliveryStatus === 'SMS_QUEUED_OFFLINE';
                    return (
                      <div key={index} style={styles.contactRow}>
                        <div style={styles.contactInfo}>
                          <span style={styles.contactName}>{contact.contactName} ({contact.relationship})</span>
                          <span style={styles.contactMobile}>{contact.contactMobile}</span>
                        </div>
                        <div
                          style={{
                            ...styles.statusBadge,
                            backgroundColor: isQueued ? 'rgba(255, 183, 3, 0.12)' : 'rgba(46, 196, 182, 0.12)',
                            border: `1.5px solid ${isQueued ? 'var(--warnings)' : 'var(--safety-green)'}`,
                          }}
                        >
                          <span style={{ ...styles.badgeText, color: isQueued ? 'var(--warnings)' : 'var(--safety-green)' }}>
                            {isQueued ? "QUEUED (OFFLINE)" : "SMS SENT"}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* Radio VHF panel */}
          <div style={styles.radioCard} className="glass-card">
            <div style={styles.radioRow}>
              <div>
                <span style={styles.radioTitle}>VHF Radio Distress Signal</span>
                <p style={styles.radioSub}>Channel 16 (156.8 MHz)</p>
              </div>
              <div
                style={{
                  ...styles.radioBadge,
                  backgroundColor: isTriggered ? 'rgba(0, 180, 216, 0.12)' : 'rgba(136, 146, 176, 0.12)',
                  border: `1px solid ${isTriggered ? 'var(--sky-blue)' : 'var(--text-muted)'}`,
                }}
              >
                <Radio size={12} color={isTriggered ? 'var(--sky-blue)' : 'var(--text-muted)'} />
                <span style={{ ...styles.badgeText, color: isTriggered ? 'var(--sky-blue)' : 'var(--text-muted)' }}>
                  {isTriggered ? "BROADCASTING" : "STANDBY"}
                </span>
              </div>
            </div>
          </div>

          {isTriggered && (
            <button id="sos-reset-btn" onClick={resetAlarm} style={styles.resetBtn}>
              Reset SOS Distress Alarm
            </button>
          )}
        </div>
      </div>

      {/* Responsive layout embedded styles */}
      <style>{`
        .sos-split-layout {
          display: flex;
          flex-direction: row;
          gap: 24px;
          align-items: flex-start;
          width: 100%;
          margin-top: 10px;
        }

        .sos-left-panel {
          flex: 1;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }

        .sos-right-panel {
          flex: 1.2;
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        @media (max-width: 768px) {
          .sos-split-layout {
            flex-direction: column;
            align-items: stretch;
          }
          .sos-left-panel {
            padding: 0;
          }
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
  sectionTitle: {
    fontSize: '18px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '1px',
    borderLeft: '4px solid var(--aquamarine)',
    paddingLeft: '10px',
  },
  topBanner: {
    display: 'flex',
    gap: '14px',
    alignItems: 'center',
    padding: '16px',
    border: '1.5px solid rgba(217, 4, 41, 0.4)',
  },
  topBannerActive: {
    border: '1.5px solid var(--safety-green)',
    borderRadius: '16px',
    padding: '16px',
    color: 'var(--text-white)',
    display: 'flex',
    gap: '14px',
    alignItems: 'center',
  },
  bannerContent: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  bannerTitle: {
    fontSize: '13px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '0.8px',
  },
  bannerText: {
    fontSize: '12px',
    color: 'var(--text-muted)',
    lineHeight: '1.4',
  },
  btnSection: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    padding: '10px 0',
  },
  sosButton: {
    width: '180px',
    height: '180px',
    borderRadius: '50%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    position: 'relative',
    userSelect: 'none',
  },
  innerCore: {
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '6px',
    zIndex: 10,
  },
  countdownText: {
    fontSize: '24px',
    fontWeight: '950',
    color: 'var(--text-white)',
  },
  statusLabelContainer: {
    textAlign: 'center',
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
    marginTop: '10px',
  },
  statusLabel: {
    fontSize: '14px',
    fontWeight: '900',
    letterSpacing: '1px',
  },
  cancelFoot: {
    fontSize: '11px',
    color: 'var(--text-muted)',
    fontStyle: 'italic',
  },
  monitorCard: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  monitorTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '12px',
    fontWeight: '900',
    color: 'var(--text-white)',
  },
  divider: {
    height: '1.5px',
    backgroundColor: 'var(--deep-navy)',
  },
  monitorLoading: {
    fontSize: '12px',
    color: 'var(--text-muted)',
  },
  contactList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
  },
  contactRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  contactInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  contactName: {
    fontSize: '12px',
    fontWeight: '700',
    color: 'var(--text-white)',
  },
  contactMobile: {
    fontSize: '11px',
    color: 'var(--text-muted)',
  },
  statusBadge: {
    padding: '4px 8px',
    borderRadius: '6px',
  },
  badgeText: {
    fontSize: '9px',
    fontWeight: '900',
    letterSpacing: '0.5px',
  },
  radioCard: {
    padding: '16px',
  },
  radioRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  radioTitle: {
    fontSize: '13px',
    fontWeight: '700',
    color: 'var(--text-white)',
  },
  radioSub: {
    fontSize: '11px',
    color: 'var(--text-muted)',
    marginTop: '2px',
  },
  radioBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '4px 8px',
    borderRadius: '6px',
  },
  resetBtn: {
    backgroundColor: 'var(--card-navy)',
    border: '1.5px solid var(--crimson-alert)',
    color: 'var(--text-white)',
    fontSize: '13px',
    fontWeight: '800',
    padding: '12px',
    borderRadius: '10px',
    cursor: 'pointer',
    width: '100%',
    marginTop: '10px',
  },
};
