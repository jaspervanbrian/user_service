import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, ApiException } from '../api';
import { useAuth } from '../context';

export const LoginPage: React.FC = () => {
  const [loginIdentifier, setLoginIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { loginWithSession } = useAuth();
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const session = await api.login(loginIdentifier, password);
      loginWithSession(session);
      navigate('/', { replace: true });
    } catch (err) {
      if (err instanceof ApiException) {
        setError(err.message || 'Invalid credentials');
      } else {
        setError('Could not connect to the backend API. Is Rails running on port 3000?');
      }
    } finally {
      setLoading(false);
    }
  };

  const quickFill = (userLogin: string, pass: string) => {
    setLoginIdentifier(userLogin);
    setPassword(pass);
    setError(null);
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <div className="login-logo">US</div>
          <h2>Sign in to User Service</h2>
          <p className="login-subtitle">
            Secure asymmetric RS256 JWT &bull; Pundit RBAC & ABAC
          </p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleLogin} className="login-form">
          <div className="form-group">
            <label htmlFor="login">Username or Email</label>
            <input
              id="login"
              type="text"
              required
              autoFocus
              placeholder="e.g. ada@example.com or MikeM"
              value={loginIdentifier}
              onChange={(e) => setLoginIdentifier(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              required
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <button type="submit" disabled={loading} className="btn btn-primary btn-block">
            {loading ? 'Authenticating...' : 'Sign in'}
          </button>
        </form>

        <div className="quick-login-section">
          <span className="quick-login-label">Quick Demo Logins (Seed Accounts)</span>
          <div className="quick-login-buttons">
            <button
              type="button"
              className="btn btn-outline btn-sm"
              onClick={() => quickFill('ada@example.com', 'password123')}
            >
              🔑 Login as Admin (Ada)
            </button>
            <button
              type="button"
              className="btn btn-outline btn-sm"
              onClick={() => quickFill('MikeM', 'password123')}
            >
              👤 Login as Member (Mike)
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
