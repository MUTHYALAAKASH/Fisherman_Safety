import React, { useState, useEffect } from 'react';
import { api } from '../services/syncManager';
import { User, Ship, Globe, Save, Users, Trash2, Plus } from 'lucide-react';
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

  const [contacts, setContacts] = useState([]);
  const [contactsLoading, setContactsLoading] = useState(false);
  const [newContactName, setNewContactName] = useState('');
  const [newContactMobile, setNewContactMobile] = useState('');
  const [newContactRel, setNewContactRel] = useState('Wife');
  const [contactsMsg, setContactsMsg] = useState('');
  const [contactsMsgType, setContactsMsgType] = useState('success');

  const languages = [
    { code: 'en', name: 'English' },
    { code: 'ta', name: 'தமிழ்' },
    { code: 'te', name: 'తెలుగు' },
    { code: 'kn', name: 'ಕನ್ನಡ' },
    { code: 'ml', name: 'മലയാളം' },
    { code: 'hi', name: 'हिन्दी' },
  ];

  const fetchContacts = async () => {
    try {
      const response = await api.get('/api/users/contacts');
      if (response.status === 200) {
        setContacts(response.data);
      }
    } catch (e) {
      console.error("Error loading contacts: ", e);
    }
  };

  useEffect(() => {
    fetchContacts();
  }, []);

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

  const handleAddContact = async (e) => {
    e.preventDefault();
    if (!newContactName.trim() || !newContactMobile.trim()) {
      setContactsMsgType('error');
      setContactsMsg('Please fill in Name and Mobile Number.');
      return;
    }
    if (newContactMobile.trim().length !== 10 || isNaN(newContactMobile.trim())) {
      setContactsMsgType('error');
      setContactsMsg('Mobile number must be exactly 10 digits.');
      return;
    }

    setContactsLoading(true);
    setContactsMsg('');
    try {
      const response = await api.post('/api/users/contacts', {
        contactName: newContactName.trim(),
        contactMobile: newContactMobile.trim(),
        relationship: newContactRel,
      });
      if (response.status === 201 || response.status === 200) {
        setContactsMsgType('success');
        setContactsMsg('Family contact registered successfully!');
        setNewContactName('');
        setNewContactMobile('');
        setNewContactRel('Wife');
        fetchContacts();
      }
    } catch (err) {
      console.error(err);
      setContactsMsgType('error');
      setContactsMsg(err.response?.data?.message || 'Failed to save contact.');
    } finally {
      setContactsLoading(false);
    }
  };

  const handleDeleteContact = async (id) => {
    if (!window.confirm("Are you sure you want to delete this emergency contact?")) {
      return;
    }
    try {
      const response = await api.delete(`/api/users/contacts/${id}`);
      if (response.status === 200) {
        setContactsMsgType('success');
        setContactsMsg('Contact removed successfully.');
        fetchContacts();
      }
    } catch (err) {
      console.error(err);
      setContactsMsgType('error');
      setContactsMsg(err.response?.data?.message || 'Failed to delete contact.');
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

        {/* Right Side: Language & Contacts */}
        <div className="lang-pane" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          {/* Language select */}
          <div style={styles.languageCard} className="glass-card">
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

          {/* Family Contacts Card */}
          <div style={styles.contactsCard} className="glass-card">
            <h3 style={styles.subTitle}>
              <Users size={18} color="var(--sky-blue)" />
              <span>Family Emergency Contacts</span>
            </h3>

            {contactsMsg && (
              <div style={{
                ...(contactsMsgType === 'success' ? styles.successBanner : styles.errorBanner),
                marginBottom: '12px'
              }}>
                {contactsMsg}
              </div>
            )}

            {/* List of saved contacts */}
            <div style={styles.contactList}>
              {contacts.length === 0 ? (
                <div style={styles.emptyList}>
                  No saved emergency contacts.
                </div>
              ) : (
                contacts.map((contact) => (
                  <div key={contact.id} style={styles.contactRow}>
                    <div style={styles.contactInfo}>
                      <span style={styles.contactNameText}>{contact.contactName}</span>
                      <span style={styles.contactSubText}>{contact.relationship} • {contact.contactMobile}</span>
                    </div>
                    <button
                      id={`delete-contact-btn-${contact.id}`}
                      type="button"
                      onClick={() => handleDeleteContact(contact.id)}
                      style={styles.deleteBtn}
                      title="Remove contact"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))
              )}
            </div>

            <div style={{ ...styles.divider, margin: '16px 0' }} />

            {/* Form to Add Custom Family Contact */}
            <form onSubmit={handleAddContact} style={styles.addContactForm}>
              <span style={styles.formHeader}>ADD FAMILY CONTACT</span>
              
              <div style={styles.inputGroup}>
                <label style={styles.label}>Full Name</label>
                <input
                  id="contact-name-input"
                  type="text"
                  placeholder="e.g. Kavita Raja"
                  value={newContactName}
                  onChange={(e) => setNewContactName(e.target.value)}
                  style={styles.input}
                  required
                />
              </div>

              <div style={styles.inputGroup}>
                <label style={styles.label}>Mobile Number</label>
                <input
                  id="contact-mobile-input"
                  type="tel"
                  placeholder="10-digit number"
                  value={newContactMobile}
                  onChange={(e) => setNewContactMobile(e.target.value)}
                  style={styles.input}
                  required
                />
              </div>

              <div style={styles.inputGroup}>
                <label style={styles.label}>Relationship</label>
                <select
                  id="contact-relationship-select"
                  value={newContactRel}
                  onChange={(e) => setNewContactRel(e.target.value)}
                  style={styles.select}
                >
                  <option value="Wife">Wife</option>
                  <option value="Husband">Husband</option>
                  <option value="Son">Son</option>
                  <option value="Daughter">Daughter</option>
                  <option value="Brother">Brother</option>
                  <option value="Sister">Sister</option>
                  <option value="Father">Father</option>
                  <option value="Mother">Mother</option>
                  <option value="Friend">Friend</option>
                  <option value="Other">Other</option>
                </select>
              </div>

              <button
                id="contact-save-btn"
                type="submit"
                disabled={contactsLoading}
                style={styles.saveContactBtn}
              >
                <Plus size={16} />
                <span>{contactsLoading ? "SAVING..." : "REGISTER CONTACT"}</span>
              </button>
            </form>
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
  contactsCard: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  contactList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    maxHeight: '200px',
    overflowY: 'auto',
  },
  contactRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '8px 12px',
    backgroundColor: 'rgba(17, 34, 64, 0.75)',
    border: '1px solid rgba(0, 119, 182, 0.15)',
    borderRadius: '8px',
  },
  contactInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  contactNameText: {
    fontSize: '12px',
    fontWeight: '800',
    color: 'var(--text-white)',
  },
  contactSubText: {
    fontSize: '10px',
    color: 'var(--text-muted)',
  },
  deleteBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--crimson-alert)',
    cursor: 'pointer',
    padding: '4px',
    display: 'flex',
    alignItems: 'center',
    transition: 'color 0.2s',
  },
  emptyList: {
    padding: '16px',
    textAlign: 'center',
    color: 'var(--text-muted)',
    fontSize: '11px',
    fontStyle: 'italic',
  },
  divider: {
    height: '1.5px',
    backgroundColor: 'rgba(0, 119, 182, 0.15)',
    width: '100%',
  },
  addContactForm: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
  },
  formHeader: {
    fontSize: '10px',
    fontWeight: '900',
    color: 'var(--text-muted)',
    letterSpacing: '0.8px',
    marginBottom: '4px',
  },
  select: {
    backgroundColor: 'var(--deep-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    borderRadius: '10px',
    padding: '10px 12px',
    color: 'var(--text-white)',
    fontSize: '13px',
    outline: 'none',
    cursor: 'pointer',
  },
  saveContactBtn: {
    marginTop: '6px',
    backgroundColor: 'var(--ocean-blue)',
    color: 'var(--text-white)',
    fontWeight: '800',
    fontSize: '12px',
    padding: '10px',
    borderRadius: '10px',
    border: 'none',
    cursor: 'pointer',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '6px',
    transition: 'background-color 0.2s',
  },
};
