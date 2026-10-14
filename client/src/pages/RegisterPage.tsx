import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { api, ApiException } from '../api';
import { useAuth } from '../context';
import { Users, UserPlus } from 'lucide-react';

export const RegisterPage: React.FC = () => {
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    username: '',
    email: '',
    password: '',
    password_confirmation: '',
    date_of_birth: '',
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { loginWithSession } = useAuth();
  const navigate = useNavigate();

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();

    if (formData.password !== formData.password_confirmation) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const payload = {
        first_name: formData.first_name.trim(),
        last_name: formData.last_name.trim(),
        username: formData.username.trim(),
        email: formData.email.trim(),
        password: formData.password,
        password_confirmation: formData.password_confirmation,
        ...(formData.date_of_birth ? { date_of_birth: formData.date_of_birth } : {}),
      };

      const session = await api.register(payload);
      loginWithSession(session);
      navigate('/', { replace: true });
    } catch (err) {
      if (err instanceof ApiException) {
        setError(err.message || 'Registration failed');
      } else {
        setError('Could not connect to the backend API. Is Rails running on port 3000?');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card login-card-register">
        <div className="login-header">
          <div className="login-logo">
            <Users size={26} />
          </div>
          <h2>Create an Account</h2>
          <p className="login-subtitle">Join the directory as a new member</p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleRegister} className="login-form">
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="reg-first-name">First Name</label>
              <input
                id="reg-first-name"
                type="text"
                required
                autoFocus
                placeholder="Alan"
                value={formData.first_name}
                onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label htmlFor="reg-last-name">Last Name</label>
              <input
                id="reg-last-name"
                type="text"
                required
                placeholder="Turing"
                value={formData.last_name}
                onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="reg-username">Username</label>
            <input
              id="reg-username"
              type="text"
              required
              placeholder="alant"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
            />
          </div>

          <div className="form-group">
            <label htmlFor="reg-email">Email</label>
            <input
              id="reg-email"
              type="email"
              required
              placeholder="alan.turing@example.com"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="reg-password">Password</label>
              <input
                id="reg-password"
                type="password"
                required
                minLength={8}
                placeholder="••••••••"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label htmlFor="reg-password-confirmation">Confirm Password</label>
              <input
                id="reg-password-confirmation"
                type="password"
                required
                minLength={8}
                placeholder="••••••••"
                value={formData.password_confirmation}
                onChange={(e) =>
                  setFormData({ ...formData, password_confirmation: e.target.value })
                }
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="reg-dob">
              Date of Birth <span className="text-muted">(Optional)</span>
            </label>
            <input
              id="reg-dob"
              type="date"
              value={formData.date_of_birth}
              onChange={(e) => setFormData({ ...formData, date_of_birth: e.target.value })}
            />
          </div>

          <button type="submit" disabled={loading} className="btn btn-primary btn-block">
            <UserPlus size={16} style={{ marginRight: '6px' }} />
            {loading ? 'Creating account...' : 'Create Account'}
          </button>
        </form>

        <div className="auth-switch-text">
          Already have an account? <Link to="/login">Sign in</Link>
        </div>
      </div>
    </div>
  );
};
