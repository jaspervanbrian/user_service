import React, { createContext, useState, useEffect } from 'react';
import type { User, SessionResponse } from '../types';

interface AuthContextType {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isAdmin: boolean;
  loginWithSession: (session: SessionResponse) => void;
  logout: () => void;
  updateUser: (user: User) => void;
}

const STORAGE_KEY = 'user_service_auth';

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [token, setToken] = useState<string | null>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as SessionResponse;
        return parsed.token;
      }
    } catch {
      // Ignore parse errors
    }
    return null;
  });

  const [user, setUser] = useState<User | null>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as SessionResponse;
        return parsed.user;
      }
    } catch {
      // Ignore parse errors
    }
    return null;
  });

  const loginWithSession = (session: SessionResponse) => {
    setToken(session.token);
    setUser(session.user);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem(STORAGE_KEY);
  };

  const updateUser = (updatedUser: User) => {
    setUser(updatedUser);
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        parsed.user = updatedUser;
        localStorage.setItem(STORAGE_KEY, JSON.stringify(parsed));
      }
    } catch {
      // Ignore parse errors
    }
  };

  // Sync state if another tab logs out or changes localStorage
  useEffect(() => {
    const handleStorage = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY) {
        if (!e.newValue) {
          setToken(null);
          setUser(null);
        } else {
          try {
            const parsed = JSON.parse(e.newValue);
            setToken(parsed.token);
            setUser(parsed.user);
          } catch {
            // Ignore parse errors
          }
        }
      }
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  const value = {
    user,
    token,
    isAuthenticated: Boolean(token && user),
    isAdmin: user?.role === 'admin',
    loginWithSession,
    logout,
    updateUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export { AuthContext, type AuthContextType };
