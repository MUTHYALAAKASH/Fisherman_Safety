import React, { useState, useEffect, useRef } from 'react';
import { api } from '../services/syncManager';
import { Search, Send, MapPin, User, MessageSquare, ArrowLeft, AlertTriangle } from 'lucide-react';
import { translate } from '../services/localizations';

export default function Chat({ currentPosition, userProfile, currentLanguage }) {
  const [selectedUser, setSelectedUser] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [attachLocation, setAttachLocation] = useState(false);

  const messagesEndRef = useRef(null);
  const pollIntervalRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    fetchContacts();
  }, []);

  useEffect(() => {
    if (selectedUser) {
      fetchHistory();
      pollIntervalRef.current = setInterval(fetchHistory, 4000);
    } else {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current);
      }
      setMessages([]);
    }

    return () => {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current);
      }
    };
  }, [selectedUser]);

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

  const handleSearch = async (e) => {
    const query = e.target.value;
    setSearchQuery(query);
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }
    try {
      const response = await api.get('/api/users/search', { params: { query } });
      if (response.status === 200) {
        setSearchResults(response.data);
      }
    } catch (err) {
      console.error("Search failed: ", err);
    }
  };

  const fetchHistory = async () => {
    if (!selectedUser) return;
    try {
      const response = await api.get(`/api/chat/history/${selectedUser.id}`);
      if (response.status === 200) {
        setMessages(response.data);
      }
    } catch (err) {
      console.error("Error loading chat history: ", err);
    }
  };

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim() && !attachLocation) return;

    const payload = {
      recipientId: selectedUser.id,
      message: newMessage,
      latitude: attachLocation ? currentPosition.latitude : null,
      longitude: attachLocation ? currentPosition.longitude : null,
      isSos: false,
    };

    try {
      const response = await api.post('/api/chat/send', payload);
      if (response.status === 201 || response.status === 200) {
        setMessages((prev) => [...prev, response.data]);
        setNewMessage('');
        setAttachLocation(false);
      }
    } catch (err) {
      console.error("Failed to send message: ", err);
    }
  };

  const addAsEmergencyContact = async (contactUser) => {
    try {
      const response = await api.post('/api/users/contacts', {
        contactUserId: contactUser.id,
        relationship: 'Colleague',
      });
      if (response.status === 201 || response.status === 200) {
        fetchContacts();
        alert(`${contactUser.fullName} added to emergency contacts list!`);
      }
    } catch (e) {
      console.error(e);
      alert(e.response?.data?.message || "Could not add emergency contact.");
    }
  };

  return (
    <div style={styles.container} className="chat-layout">
      {/* 1. Left List Pane */}
      <div style={styles.contactsPane} className={`contacts-pane ${selectedUser ? 'hidden-mobile' : ''}`}>
        <h2 style={styles.sectionTitle}>{translate('contacts', currentLanguage).toUpperCase()}</h2>

        {/* Search bar */}
        <div style={styles.searchBar} className="glass-card">
          <Search size={18} color="var(--text-muted)" />
          <input
            id="contact-search-input"
            type="text"
            value={searchQuery}
            onChange={handleSearch}
            placeholder="Search name or mobile..."
            style={styles.searchInput}
          />
        </div>

        {/* Search Results */}
        {searchResults.length > 0 && (
          <div style={styles.section}>
            <span style={styles.sectionHeader}>SEARCH RESULTS</span>
            <div style={styles.list}>
              {searchResults.map((user) => (
                <div key={user.id} style={styles.listItem} className="glass-card" onClick={() => setSelectedUser(user)}>
                  <User size={18} color="var(--sky-blue)" />
                  <div>
                    <span style={styles.listName}>{user.fullName}</span>
                    <span style={styles.listSub}>{user.mobileNumber}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Contacts list */}
        <div style={styles.section}>
          <span style={styles.sectionHeader}>SAVED CONTACTS</span>
          {contacts.length === 0 ? (
            <div style={styles.emptyList}>
              <p>No saved emergency contacts. Search users above to open conversations.</p>
            </div>
          ) : (
            <div style={styles.list}>
              {contacts.map((contact) => (
                <div
                  key={contact.id}
                  style={{
                    ...styles.listItem,
                    backgroundColor: selectedUser?.id === contact.contactUserId ? 'rgba(0, 245, 212, 0.08)' : 'rgba(17, 34, 64, 0.75)',
                    borderColor: selectedUser?.id === contact.contactUserId ? 'var(--aquamarine)' : 'rgba(0, 119, 182, 0.25)',
                    opacity: contact.contactUserId ? 1 : 0.7,
                  }}
                  className="glass-card"
                  onClick={() => {
                    if (contact.contactUserId) {
                      setSelectedUser({ id: contact.contactUserId, fullName: contact.contactName });
                    } else {
                      alert(`${contact.contactName} is registered as an offline/SMS family contact. Secure chat room is only available for registered users who have created an account on the platform.`);
                    }
                  }}
                >
                  <User size={18} color="var(--aquamarine)" />
                  <div>
                    <span style={styles.listName}>{contact.contactName}</span>
                    <span style={styles.listSub}>{contact.relationship} • {contact.contactMobile} {!contact.contactUserId && "(SMS-only)"}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 2. Right Conversation Pane */}
      <div style={styles.conversationPane} className={`conversation-pane ${!selectedUser ? 'hidden-mobile' : ''}`}>
        {selectedUser ? (
          <div style={styles.chatRoom}>
            {/* Header */}
            <div style={styles.header}>
              <button id="chat-back-btn" onClick={() => setSelectedUser(null)} style={styles.backBtn} className="back-btn-mobile-only">
                <ArrowLeft size={20} />
              </button>
              <div style={styles.headerInfo}>
                <span style={styles.headerName}>{selectedUser.fullName || selectedUser.contactName}</span>
                <span style={styles.headerSub}>{selectedUser.role || "Emergency Contact"}</span>
              </div>
              {!contacts.some(c => c.contactUserId === selectedUser.id) && (
                <button onClick={() => addAsEmergencyContact(selectedUser)} style={styles.addContactBtn}>
                  + ADD CONTACT
                </button>
              )}
            </div>

            {/* Message History */}
            <div style={styles.messagesContainer}>
              {messages.length === 0 ? (
                <div style={styles.emptyChat}>
                  <MessageSquare size={36} color="var(--text-muted)" />
                  <p>Send a location or message to start securing communications.</p>
                </div>
              ) : (
                messages.map((msg) => {
                  if (msg.isSos) {
                    return (
                      <div
                        key={msg.id}
                        style={{
                          display: 'flex',
                          justifyContent: 'center',
                          width: '100%',
                          margin: '12px 0',
                        }}
                      >
                        <div
                          style={{
                            maxWidth: '85%',
                            padding: '16px',
                            borderRadius: '16px',
                            backgroundColor: 'rgba(217, 4, 41, 0.12)',
                            border: '2px solid var(--crimson-alert)',
                            boxShadow: '0 4px 12px rgba(217, 4, 41, 0.2)',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '8px',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--crimson-alert)', fontWeight: 'bold', fontSize: '14px' }}>
                            <AlertTriangle size={18} />
                            <span>🚨 ACTIVE SOS SIGNAL</span>
                          </div>
                          <p style={{ ...styles.bubbleText, fontWeight: 'bold', textAlign: 'center' }}>{msg.message}</p>
                          {msg.latitude && msg.longitude && (
                            <a
                              href={`https://www.openstreetmap.org/?mlat=${msg.latitude}&mlon=${msg.longitude}#map=15/${msg.latitude}/${msg.longitude}`}
                              target="_blank"
                              rel="noreferrer"
                              style={{
                                ...styles.locationTag,
                                color: 'var(--crimson-alert)',
                                justifyContent: 'center',
                                border: '1px solid var(--crimson-alert)',
                                borderRadius: '8px',
                                padding: '8px 12px',
                                textDecoration: 'none',
                                marginTop: '4px',
                                backgroundColor: 'rgba(217, 4, 41, 0.08)'
                              }}
                            >
                              <MapPin size={14} />
                              <span>Locate Distress Signal ({msg.latitude.toFixed(4)}, {msg.longitude.toFixed(4)})</span>
                            </a>
                          )}
                          <span style={{ ...styles.bubbleTime, color: 'rgba(248, 249, 250, 0.4)' }}>
                            {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </span>
                        </div>
                      </div>
                    );
                  }

                  const isMe = msg.senderId === userProfile.id;
                  return (
                    <div
                      key={msg.id}
                      style={{
                        ...styles.messageRow,
                        justifyContent: isMe ? 'flex-end' : 'flex-start',
                      }}
                    >
                      <div
                        style={{
                          ...styles.bubble,
                          backgroundColor: isMe ? 'var(--safety-green)' : 'var(--card-navy)',
                          border: isMe ? 'none' : '1px solid rgba(0, 119, 182, 0.25)',
                        }}
                      >
                        <p style={styles.bubbleText}>{msg.message}</p>
                        {msg.latitude && msg.longitude && (
                          <a
                            href={`https://www.openstreetmap.org/?mlat=${msg.latitude}&mlon=${msg.longitude}#map=15/${msg.latitude}/${msg.longitude}`}
                            target="_blank"
                            rel="noreferrer"
                            style={styles.locationTag}
                          >
                            <MapPin size={12} />
                            <span>Locate Vessel ({msg.latitude.toFixed(4)}, {msg.longitude.toFixed(4)})</span>
                          </a>
                        )}
                        <span style={styles.bubbleTime}>
                          {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input area */}
            <form onSubmit={handleSendMessage} style={styles.inputArea} className="glass-card">
              {attachLocation && (
                <div style={styles.attachmentBanner}>
                  <MapPin size={14} color="var(--aquamarine)" />
                  <span>GPS Location Attached ({currentPosition.latitude.toFixed(4)}, {currentPosition.longitude.toFixed(4)})</span>
                  <button type="button" onClick={() => setAttachLocation(false)} style={styles.detachBtn}>
                    Remove
                  </button>
                </div>
              )}
              <div style={styles.inputRow}>
                <button
                  id="chat-attach-location-btn"
                  type="button"
                  onClick={() => setAttachLocation(!attachLocation)}
                  style={attachLocation ? styles.attachBtnActive : styles.attachBtn}
                >
                  <MapPin size={20} />
                </button>
                <input
                  id="chat-message-input"
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Type secure message here..."
                  style={styles.input}
                />
                <button id="chat-send-btn" type="submit" style={styles.sendBtn}>
                  <Send size={18} />
                </button>
              </div>
            </form>
          </div>
        ) : (
          <div style={styles.selectChatBanner}>
            <MessageSquare size={48} color="var(--text-muted)" style={{ opacity: 0.5 }} />
            <p>Select a contact from the panel to open secure chat log</p>
          </div>
        )}
      </div>

      {/* Embedded CSS rules for responsive collapse */}
      <style>{`
        .chat-layout {
          display: flex;
          flex-direction: row;
          height: 100%;
          width: 100%;
        }

        .contacts-pane {
          width: 320px;
          border-right: 1.5px solid rgba(0, 119, 182, 0.15);
          display: flex;
          flex-direction: column;
          gap: 16px;
          padding: 20px;
          overflow-y: auto;
          flex-shrink: 0;
        }

        .conversation-pane {
          flex: 1;
          height: 100%;
          display: flex;
          flex-direction: column;
        }

        .back-btn-mobile-only {
          display: none;
        }

        @media (max-width: 768px) {
          .contacts-pane {
            width: 100%;
            border-right: none;
          }

          .contacts-pane.hidden-mobile {
            display: none !important;
          }

          .conversation-pane.hidden-mobile {
            display: none !important;
          }

          .back-btn-mobile-only {
            display: flex !important;
          }
        }
      `}</style>
    </div>
  );
}

const styles = {
  container: {
    height: '100%',
    width: '100%',
  },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: '900',
    color: 'var(--text-white)',
    letterSpacing: '1px',
    borderLeft: '4px solid var(--aquamarine)',
    paddingLeft: '10px',
  },
  searchBar: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 16px',
    flexShrink: 0,
  },
  searchInput: {
    background: 'none',
    border: 'none',
    outline: 'none',
    color: 'var(--text-white)',
    fontSize: '13px',
    flex: 1,
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  sectionHeader: {
    fontSize: '10px',
    fontWeight: '900',
    color: 'var(--text-muted)',
    letterSpacing: '0.8px',
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  listItem: {
    padding: '12px 14px',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    cursor: 'pointer',
    transition: 'border-color 0.2s',
  },
  listName: {
    display: 'block',
    fontSize: '13px',
    fontWeight: '700',
    color: 'var(--text-white)',
  },
  listSub: {
    display: 'block',
    fontSize: '11px',
    color: 'var(--text-muted)',
    marginTop: '2px',
  },
  emptyList: {
    padding: '20px 10px',
    textAlign: 'center',
    color: 'var(--text-muted)',
    fontSize: '12px',
    lineHeight: '1.5',
  },
  chatRoom: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    width: '100%',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    padding: '14px 16px',
    backgroundColor: 'var(--card-navy)',
    borderBottom: '1.5px solid rgba(0, 119, 182, 0.25)',
  },
  backBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--text-white)',
    cursor: 'pointer',
    alignItems: 'center',
    paddingRight: '12px',
  },
  headerInfo: {
    display: 'flex',
    flexDirection: 'column',
    flex: 1,
  },
  headerName: {
    fontSize: '14px',
    fontWeight: '800',
    color: 'var(--text-white)',
  },
  headerSub: {
    fontSize: '10px',
    color: 'var(--text-muted)',
  },
  addContactBtn: {
    backgroundColor: 'var(--card-navy)',
    border: '1.5px solid var(--aquamarine)',
    color: 'var(--aquamarine)',
    fontSize: '10px',
    fontWeight: '800',
    padding: '6px 10px',
    borderRadius: '6px',
    cursor: 'pointer',
  },
  messagesContainer: {
    flex: 1,
    overflowY: 'auto',
    padding: '16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
    backgroundColor: 'rgba(3, 12, 27, 0.2)',
  },
  emptyChat: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    color: 'var(--text-muted)',
    gap: '8px',
    fontSize: '12px',
    textAlign: 'center',
    padding: '0 24px',
  },
  messageRow: {
    display: 'flex',
    width: '100%',
  },
  bubble: {
    maxWidth: '75%',
    padding: '10px 14px',
    borderRadius: '16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  bubbleText: {
    fontSize: '13px',
    color: 'var(--text-white)',
    lineHeight: '1.4',
    wordBreak: 'break-word',
  },
  locationTag: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '11px',
    color: 'var(--aquamarine)',
    fontWeight: '700',
    textDecoration: 'underline',
    marginTop: '4px',
  },
  bubbleTime: {
    fontSize: '9px',
    color: 'rgba(248, 249, 250, 0.5)',
    alignSelf: 'flex-end',
  },
  inputArea: {
    padding: '12px 16px 16px 16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    borderRadius: '0',
    borderLeft: 'none',
    borderRight: 'none',
    borderBottom: 'none',
  },
  attachmentBanner: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: 'rgba(0, 245, 212, 0.1)',
    border: '1px solid var(--aquamarine)',
    borderRadius: '8px',
    padding: '6px 10px',
    fontSize: '11px',
    color: 'var(--text-white)',
  },
  detachBtn: {
    marginLeft: 'auto',
    background: 'none',
    border: 'none',
    color: 'var(--crimson-alert)',
    fontWeight: '700',
    cursor: 'pointer',
    fontSize: '11px',
  },
  inputRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
  },
  attachBtn: {
    backgroundColor: 'var(--deep-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    color: 'var(--text-muted)',
    borderRadius: '50%',
    width: '40px',
    height: '40px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
  },
  attachBtnActive: {
    backgroundColor: 'rgba(0, 245, 212, 0.15)',
    border: '1.5px solid var(--aquamarine)',
    color: 'var(--aquamarine)',
    borderRadius: '50%',
    width: '40px',
    height: '40px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
  },
  input: {
    flex: 1,
    backgroundColor: 'var(--deep-navy)',
    border: '1.5px solid rgba(0, 119, 182, 0.25)',
    borderRadius: '20px',
    padding: '10px 16px',
    color: 'var(--text-white)',
    fontSize: '13px',
    outline: 'none',
  },
  sendBtn: {
    backgroundColor: 'var(--ocean-blue)',
    color: 'var(--text-white)',
    borderRadius: '50%',
    width: '40px',
    height: '40px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    border: 'none',
    cursor: 'pointer',
    boxShadow: '0 4px 10px rgba(0, 119, 182, 0.3)',
  },
  selectChatBanner: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    color: 'var(--text-muted)',
    gap: '12px',
    fontSize: '13px',
  },
};
