import React, { useState } from 'react';
import { api } from '../services/syncManager';
import { Anchor, ShieldAlert, Navigation } from 'lucide-react';
import { translate } from '../services/localizations';

export default function LoginRegister({ onAuthSuccess, currentLanguage }) {
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Form Fields
  const [fullName, setFullName] = useState('');
  const [mobileNumber, setMobileNumber] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [boatName, setBoatName] = useState('');
  const [registrationNumber, setRegistrationNumber] = useState('');
  const [harborLocation, setHarborLocation] = useState('');

  const validateMobile = (mobile, isRegisterMode) => {
    if (!mobile) return "Please enter mobile number";
    if (!/^\d+$/.test(mobile)) return "Mobile number must contain only digits";
    if (isRegisterMode) {
      if (mobile.length !== 10) return "Mobile number must be exactly 10 digits";
    } else {
      if (mobile.length < 4 || mobile.length > 15) return "Mobile number must be between 4 and 15 digits";
    }
    return null;
  };

  const validatePassword = (pass, isRegisterMode) => {
    if (!pass) return "Password is required";
    if (isRegisterMode) {
      if (pass.length < 6) return "Password must be at least 6 characters";
    }
    return null;
  };

  const handleAuth = async (e) => {
    e.preventDefault();
    setError('');

    // Pre-validations
    const mobError = validateMobile(mobileNumber, isRegister);
    if (mobError) {
      setError(mobError);
      return;
    }

    const passError = validatePassword(password, isRegister);
    if (passError) {
      setError(passError);
      return;
    }

    if (isRegister) {
      if (!fullName) {
        setError("Please enter full name");
        return;
      }
      if (boatName && !registrationNumber) {
        setError("Registration number required if Boat Name is filled");
        return;
      }
    }

    setLoading(true);
    try {
      if (isRegister) {
        const response = await api.post('/api/auth/signup', {
          fullName,
          mobileNumber,
          email: email || null,
          password,
          role: 'FISHERMAN',
          boatName: boatName || null,
          registrationNumber: registrationNumber || null,
          harborLocation: harborLocation || null,
        });

        if (response.status === 201 || response.status === 200) {
          // Switch to login automatically
          setIsRegister(false);
          setError('');
          alert("Registration successful! Please Sign In.");
        }
      } else {
        const response = await api.post('/api/auth/signin', {
          mobileNumber,
          password,
        });

        if (response.status === 200) {
          const { token } = response.data;
          localStorage.setItem('jwt_token', token);

          // Get user details
          const profileRes = await api.get('/api/users/profile');
          if (profileRes.status === 200) {
            localStorage.setItem('user_profile', JSON.stringify(profileRes.data));
            onAuthSuccess(profileRes.data);
          }
        }
      }
    } catch (e) {
      console.error(e);
      const msg = e.response?.data?.message || e.message || "Operation failed. Check backend server connection.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.outerContainer}>
      <div style={styles.card} className="glass-card">
        {/* Brand Header */}
        <div style={styles.brandContainer}>
          <div style={styles.iconRing}>
            <Navigation size={32} style={styles.navIcon} />
          </div>
          <h1 style={styles.title}>{translate('appTitle', currentLanguage)}</h1>
          <p style={styles.subtitle}>DEEP SEA NAVIGATION & MONITORS</p>
        </div>

        {error && (
          <div style={styles.errorBanner}>
            <ShieldAlert size={20} color="var(--crimson-alert)" />
            <span style={styles.errorText}>{error}</span>
          </div>
        )}

        <form onSubmit={handleAuth} style={styles.form}>
          {isRegister && (
            <div style={styles.inputGroup}>
              <label style={styles.label}>{translate('fullName', currentLanguage)}</label>
              <input
                id="full-name-input"
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                style={styles.input}
                placeholder="Fisherman Name"
                required
              />
            </div>
          )}

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('mobileNumber', currentLanguage)}</label>
            <input
              id="mobile-number-input"
              type="text"
              value={mobileNumber}
              onChange={(e) => setMobileNumber(e.target.value)}
              style={styles.input}
              placeholder="e.g. 9876543210"
              required
            />
          </div>

          {isRegister && (
            <div style={styles.inputGroup}>
              <label style={styles.label}>Email Address (Optional)</label>
              <input
                id="email-input"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={styles.input}
                placeholder="email@example.com"
              />
            </div>
          )}

          <div style={styles.inputGroup}>
            <label style={styles.label}>{translate('password', currentLanguage)}</label>
            <input
              id="password-input"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={styles.input}
              placeholder="Min 6 characters"
              required
            />
          </div>

          {isRegister && (
            <>
              <div style={styles.inputGroup}>
                <label style={styles.label}>{translate('boatName', currentLanguage)}</label>
                <input
                  id="boat-name-input"
                  type="text"
                  value={boatName}
                  onChange={(e) => setBoatName(e.target.value)}
                  style={styles.input}
                  placeholder="Vessel Name"
                />
              </div>

              <div style={styles.inputGroup}>
                <label style={styles.label}>{translate('regNumber', currentLanguage)}</label>
                <input
                  id="reg-number-input"
                  type="text"
                  value={registrationNumber}
                  onChange={(e) => setRegistrationNumber(e.target.value)}
                  style={styles.input}
                  placeholder="Vessel registration number"
                />
              </div>

              <div style={styles.inputGroup}>
                <label style={styles.label}>{translate('harbor', currentLanguage)}</label>
                <input
                  id="harbor-input"
                  type="text"
                  value={harborLocation}
                  onChange={(e) => setHarborLocation(e.target.value)}
                  style={styles.input}
                  placeholder="Base port location"
                />
              </div>
            </>
          )}

          <button id="auth-submit-btn" type="submit" disabled={loading} style={styles.submitBtn}>
            {loading
              ? "CONNECTING..."
              : isRegister
              ? translate('signup', currentLanguage).toUpperCase()
              : translate('signin', currentLanguage).toUpperCase()}
          </button>
        </form>

        <div style={styles.toggleText}>
          {isRegister ? "Already registered?" : "New Vessel?"}{' '}
          <span
            id="toggle-auth-btn"
            onClick={() => {
              setIsRegister(!isRegister);
              setError('');
            }}
            style={styles.toggleLink}
          >
            {isRegister ? "Sign In Instead" : "Register Vessel"}
          </span>
        </div>
      </div>
    </div>
  );
}

const styles = {
  outerContainer: {
    padding: '24px',
    width: '100%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    width: '100%',
    maxWidth: '400px',
    padding: '32px 24px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'stretch',
  },
  brandContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    marginBottom: '24px',
  },
  iconRing: {
    width: '64px',
    height: '64px',
    borderRadius: '50%',
    backgroundColor: 'rgba(0, 119, 182, 0.15)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    border: '1.5px solid var(--sky-blue)',
    marginBottom: '12px',
  },
  navIcon: {
    color: 'var(--aquamarine)',
    transform: 'rotate(45deg)',
  },
  title: {
    fontSize: '20px',
    fontWeight: '900',
    color: 'var(--text-white)',
    textAlign: 'center',
    marginBottom: '4px',
    letterSpacing: '0.5px',
  },
  subtitle: {
    fontSize: '10px',
    fontWeight: '700',
    color: 'var(--text-muted)',
    letterSpacing: '1.5px',
  },
  errorBanner: {
    backgroundColor: 'rgba(217, 4, 41, 0.1)',
    border: '1px solid var(--crimson-alert)',
    borderRadius: '12px',
    padding: '12px',
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '20px',
  },
  errorText: {
    fontSize: '12px',
    color: 'var(--text-white)',
    fontWeight: '600',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
    marginBottom: '20px',
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '6px',
  },
  label: {
    fontSize: '12px',
    fontWeight: '700',
    color: 'var(--text-muted)',
    letterSpacing: '0.5px',
  },
  input: {
    backgroundColor: 'var(--deep-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    borderRadius: '10px',
    padding: '12px',
    color: 'var(--text-white)',
    fontSize: '14px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  submitBtn: {
    marginTop: '10px',
    backgroundColor: 'var(--ocean-blue)',
    color: 'var(--text-white)',
    fontWeight: '800',
    fontSize: '14px',
    letterSpacing: '0.8px',
    padding: '14px',
    borderRadius: '12px',
    border: 'none',
    cursor: 'pointer',
    boxShadow: '0 4px 12px rgba(0, 119, 182, 0.35)',
    transition: 'background-color 0.2s',
  },
  toggleText: {
    textAlign: 'center',
    fontSize: '12px',
    color: 'var(--text-muted)',
  },
  toggleLink: {
    color: 'var(--sky-blue)',
    fontWeight: '700',
    cursor: 'pointer',
    textDecoration: 'underline',
  },
};
