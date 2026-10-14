import React, { useState } from 'react';
import type { User, CreateUserInput, Role } from '../types';
import { api, ApiException } from '../api';
import { useAuth } from '../context';

interface CreateUserModalProps {
  onClose: () => void;
  onSuccess: (createdUser: User) => void;
}

export const CreateUserModal: React.FC<CreateUserModalProps> = ({ onClose, onSuccess }) => {
  const { token } = useAuth();

  const [formData, setFormData] = useState<CreateUserInput>({
    first_name: '',
    last_name: '',
    username: '',
    email: '',
    date_of_birth: '',
    password: '',
    password_confirmation: '',
    role: 'member',
  });

  const [loading, setLoading] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({});
  const [generalError, setGeneralError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) return;

    setLoading(true);
    setFieldErrors({});
    setGeneralError(null);

    const payload: CreateUserInput = {
      first_name: formData.first_name,
      last_name: formData.last_name,
      username: formData.username,
      email: formData.email,
      password: formData.password,
      password_confirmation: formData.password_confirmation,
      role: formData.role,
    };

    if (formData.date_of_birth && formData.date_of_birth.trim() !== '') {
      payload.date_of_birth = formData.date_of_birth;
    }

    try {
      const response = await api.createUser(token, payload);
      onSuccess(response.user);
    } catch (err) {
      if (err instanceof ApiException) {
        if (err.data.errors) {
          setFieldErrors(err.data.errors);
        } else {
          setGeneralError(err.message);
        }
      } else {
        setGeneralError('Failed to create user. Please check your connection.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Create New User</h3>
          <button className="modal-close" onClick={onClose} aria-label="Close modal">
            &times;
          </button>
        </div>

        {generalError && <div className="alert alert-error">{generalError}</div>}

        <form onSubmit={handleSubmit} className="modal-form">
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="c_first_name">First Name *</label>
              <input
                id="c_first_name"
                type="text"
                required
                value={formData.first_name}
                onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
              />
              {fieldErrors.first_name && (
                <span className="field-error">{fieldErrors.first_name.join(', ')}</span>
              )}
            </div>

            <div className="form-group">
              <label htmlFor="c_last_name">Last Name *</label>
              <input
                id="c_last_name"
                type="text"
                required
                value={formData.last_name}
                onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
              />
              {fieldErrors.last_name && (
                <span className="field-error">{fieldErrors.last_name.join(', ')}</span>
              )}
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="c_username">Username *</label>
              <input
                id="c_username"
                type="text"
                required
                placeholder="letters, numbers, underscores"
                value={formData.username}
                onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              />
              {fieldErrors.username && (
                <span className="field-error">{fieldErrors.username.join(', ')}</span>
              )}
            </div>

            <div className="form-group">
              <label htmlFor="c_role">Role *</label>
              <select
                id="c_role"
                value={formData.role}
                onChange={(e) => setFormData({ ...formData, role: e.target.value as Role })}
              >
                <option value="member">member</option>
                <option value="admin">admin</option>
              </select>
              {fieldErrors.role && (
                <span className="field-error">{fieldErrors.role.join(', ')}</span>
              )}
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="c_email">Email Address *</label>
            <input
              id="c_email"
              type="email"
              required
              placeholder="user@example.com"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            />
            {fieldErrors.email && (
              <span className="field-error">{fieldErrors.email.join(', ')}</span>
            )}
          </div>

          <div className="form-group">
            <label htmlFor="c_date_of_birth">Date of Birth (optional, must be in past)</label>
            <input
              id="c_date_of_birth"
              type="date"
              value={formData.date_of_birth}
              onChange={(e) => setFormData({ ...formData, date_of_birth: e.target.value })}
            />
            {fieldErrors.date_of_birth && (
              <span className="field-error">{fieldErrors.date_of_birth.join(', ')}</span>
            )}
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="c_password">Password * (min 8 chars)</label>
              <input
                id="c_password"
                type="password"
                required
                placeholder="••••••••"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              />
              {fieldErrors.password && (
                <span className="field-error">{fieldErrors.password.join(', ')}</span>
              )}
            </div>

            <div className="form-group">
              <label htmlFor="c_password_confirmation">Confirm Password *</label>
              <input
                id="c_password_confirmation"
                type="password"
                required
                placeholder="••••••••"
                value={formData.password_confirmation}
                onChange={(e) =>
                  setFormData({ ...formData, password_confirmation: e.target.value })
                }
              />
              {fieldErrors.password_confirmation && (
                <span className="field-error">
                  {fieldErrors.password_confirmation.join(', ')}
                </span>
              )}
            </div>
          </div>

          <div className="modal-actions">
            <button type="button" onClick={onClose} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={loading} className="btn btn-primary">
              {loading ? 'Creating...' : 'Create User'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
