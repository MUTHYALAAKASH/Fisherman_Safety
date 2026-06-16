import React, { useState } from 'react';
import { api } from '../services/syncManager';
import { User, Ship, Globe, Save } from 'lucide-react';
import { translate } from '../services/localizations';

export default function ProfileSettings({ userProfile, onProfileUpdate, onLogout, currentLanguage, onLanguageChange }) {
  const [fullName, setFullName] = useState(userProfile.fullName || '');
  const [email, setEmail] = useState(userProfile.email || '');
  const [boatName, setBoatName] = useState(userProfile.boatName || '');
  const [registrationNumber, setRegistrationNumber] = useState(userProfile.registrationNumber || '');
  const [harborLocation, setHarborLocation] = useState(userProfile.harborLocation || '');
  
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState('');
  const [msgType, setMsgType] = useState('success');

  const languages = [
    { code: 'en', name: 'English' },
    { code: 'ta', name: 'தமிழ்' },
    { code: 'te', name: 'తెలుగు' },
    { code: 'kn', name: 'ಕನ್ನಡ' },
    { code: 'ml', name: 'മലയാളം' },
    { code: 'hi', name: 'हिन्दी' },
  ];

  const handleUpdate = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMsg('');
    try {
      const response = await api.put('/api/users/profile', {
        fullName,
        mobileNumber: userProfile.mobileNumber,
        email: email || null,
        role: userProfile.role || 'FISHERMAN',
        boatName: boatName || null,
        registrationNumber: registrationNumber || null,
        harborLocation: harborLocation || null,
      });

      if (response.status === 200) {
        localStorage.setItem('user_profile', JSON.stringify(response.data));
        onProfileUpdate(response.data);
        setMsgType('success');
        setMsg('Profile updated successfully!');
      }
    } catch (err) {
      console.error(err);
      setMsgType('error');
      setMsg(err.response?.data?.message || err.message || 'Failed to update profile.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.scrollContainer} className="profile-container">
      {/* Title */}
      <h2 style={styles.sectionTitle}>{translate('profile', currentLanguage).toUpperCase()}</h2>

      {msg && (
        <div style={msgType === 'success' ? styles.successBanner : styles.errorBanner}>
          {msg}
        </div>
      )}

      {/* Split Layout */}
      <div className="profile-split-layout">
        {/* Left Side: Profile Forms */}
        <form onSubmit={handleUpdate} style={styles.form} className="glass-card profile-form-pane">
          <h3 style={styles.subTitle}>
            <User size={18} color="var(--sky-blue)" />
            <span>Fisherman Profile</span>
          </h3>

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('fullName', currentLanguage)}</label>
            <input
              id="profile-name-input"
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              style={styles.input}
              required
            />
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('mobileNumber', currentLanguage)} (Read-only)</label>
            <input
              type="text"
              value={userProfile.mobileNumber}
              style={styles.disabledInput}
              disabled
            />
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>Email Address</label>
            <input
              id="profile-email-input"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              style={styles.input}
            />
          </div>

          <h3 style={{ ...styles.subTitle, marginTop: '16px' }}>
            <Ship size={18} color="var(--sky-blue)" />
            <span>{translate('boatName', currentLanguage)} Details</span>
          </h3>

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('boatName', currentLanguage)}</label>
            <input
              id="profile-boat-name-input"
              type="text"
              value={boatName}
              onChange={(e) => setBoatName(e.target.value)}
              style={styles.input}
            />
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('regNumber', currentLanguage)}</label>
            <input
              id="profile-reg-number-input"
              type="text"
              value={registrationNumber}
              onChange={(e) => setRegistrationNumber(e.target.value)}
              style={styles.input}
            />
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('harbor', currentLanguage)}</label>
            <input
              id="profile-harbor-input"
              type="text"
              value={harborLocation}
              onChange={(e) => setHarborLocation(e.target.value)}
              style={styles.input}
            />
          </div>

          <button id="profile-save-btn" type="submit" disabled={loading} style={styles.saveBtn}>
            <Save size={18} />
            <span>{loading ? "SAVING..." : "SAVE PROFILE"}</span>
          </button>
        </form>

        {/* Right Side: Language select */}
        <div style={styles.languageCard} className="glass-card lang-pane">
          <h3 style={styles.subTitle}>
            <Globe size={18} color="var(--sky-blue)" />
            <span>{translate('changeLanguage', currentLanguage)}</span>
          </h3>
          <div style={styles.langGrid}>
            {languages.map((lang) => (
              <button
                id={`lang-btn-${lang.code}`}
                key={lang.code}
                type="button"
                onClick={() => onLanguageChange(lang.code)}
                style={
                  currentLanguage === lang.code ? styles.langBtnActive : styles.langBtn
                }
              >
                {lang.name}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div style={{ height: '36px' }} />

      {/* Embedded CSS rules for profile responsive layout */}
      <style>{`
        .profile-split-layout {
          display: flex;
          flex-direction: row;
          gap: 24px;
          align-items: flex-start;
          width: 100%;
        }

        .profile-form-pane {
          flex: 1.3;
        }

        .lang-pane {
          flex: 0.7;
        }

        @media (max-width: 768px) {
          .profile-split-layout {
            flex-direction: column;
            align-items: stretch;
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
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  subTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '13px',
    fontWeight: '800',
    color: 'var(--text-white)',
    borderBottom: '1px solid rgba(0, 119, 182, 0.15)',
    paddingBottom: '8px',
    marginBottom: '8px',
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  label: {
    fontSize: '11px',
    fontWeight: '700',
    color: 'var(--text-muted)',
    letterSpacing: '0.5px',
  },
  input: {
    backgroundColor: 'var(--deep-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    borderRadius: '10px',
    padding: '10px 12px',
    color: 'var(--text-white)',
    fontSize: '13px',
    outline: 'none',
  },
  disabledInput: {
    backgroundColor: 'rgba(3, 12, 27, 0.5)',
    border: '1.5px solid rgba(0, 119, 182, 0.1)',
    borderRadius: '10px',
    padding: '10px 12px',
    color: 'var(--text-muted)',
    fontSize: '13px',
    cursor: 'not-allowed',
  },
  saveBtn: {
    marginTop: '8px',
    backgroundColor: 'var(--ocean-blue)',
    color: 'var(--text-white)',
    fontWeight: '800',
    fontSize: '13px',
    padding: '12px',
    borderRadius: '10px',
    border: 'none',
    cursor: 'pointer',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '8px',
  },
  languageCard: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  langGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '8px',
  },
  langBtn: {
    backgroundColor: 'var(--deep-navy)',
    border: '1px solid rgba(0, 119, 182, 0.2)',
    color: 'var(--text-muted)',
    borderRadius: '8px',
    padding: '10px',
    fontSize: '12px',
    fontWeight: '700',
    cursor: 'pointer',
  },
  langBtnActive: {
    backgroundColor: 'rgba(0, 245, 212, 0.12)',
    border: '1.5px solid var(--aquamarine)',
    color: 'var(--aquamarine)',
    borderRadius: '8px',
    padding: '10px',
    fontSize: '12px',
    fontWeight: '800',
    cursor: 'pointer',
  },
  successBanner: {
    backgroundColor: 'rgba(46, 196, 182, 0.15)',
    border: '1px solid var(--safety-green)',
    color: 'var(--text-white)',
    borderRadius: '10px',
    padding: '10px 14px',
    fontSize: '12px',
    fontWeight: '700',
  },
  errorBanner: {
    backgroundColor: 'rgba(217, 4, 41, 0.1)',
    border: '1px solid var(--crimson-alert)',
    color: 'var(--text-white)',
    borderRadius: '10px',
    padding: '10px 14px',
    fontSize: '12px',
    fontWeight: '700',
  },
};
