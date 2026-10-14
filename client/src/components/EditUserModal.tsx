import React, { useState } from 'react';
import type { User, UpdateUserInput, Role } from '../types';
import { api, ApiException } from '../api';
import { useAuth } from '../context';

interface EditUserModalProps {
  user: User;
  onClose: () => void;
  onSuccess: (updatedUser: User) => void;
}

export const EditUserModal: React.FC<EditUserModalProps> = ({ user, onClose, onSuccess }) => {
  const { token, user: currentUser, isAdmin, updateUser: updateAuthUser } = useAuth();
  const isEditingSelf = currentUser?.id === user.id;

  const [formData, setFormData] = useState<UpdateUserInput>({
    first_name: user.first_name,
    last_name: user.last_name,
    username: user.username,
    email: user.email || '',
    date_of_birth: user.date_of_birth || '',
    role: user.role,
    password: '',
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

    // Build payload: exclude empty password, and exclude role if not admin
    const payload: UpdateUserInput = {
      first_name: formData.first_name,
      last_name: formData.last_name,
      username: formData.username,
    };

    if (formData.email !== undefined && formData.email !== '') {
      payload.email = formData.email;
    }

    if (formData.date_of_birth !== undefined) {
      payload.date_of_birth = formData.date_of_birth === '' ? null : formData.date_of_birth;
    }

    if (formData.password && formData.password.trim() !== '') {
      payload.password = formData.password;
    }

    if (isAdmin && formData.role) {
      payload.role = formData.role;
    }

    try {
      const response = await api.updateUser(token, user.id, payload);
      if (isEditingSelf) {
        updateAuthUser(response.user);
      }
      onSuccess(response.user);
    } catch (err) {
      if (err instanceof ApiException) {
        if (err.data.errors) {
          setFieldErrors(err.data.errors);
        } else {
          setGeneralError(err.message);
        }
      } else {
        setGeneralError('Failed to update user. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Edit User: @{user.username} {isEditingSelf && <span className="text-muted">(You)</span>}</h3>
          <button className="modal-close" onClick={onClose} aria-label="Close modal">
            &times;
          </button>
        </div>

        {generalError && <div className="alert alert-error">{generalError}</div>}

        <form onSubmit={handleSubmit} className="modal-form">
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="first_name">First Name</label>
              <input
                id="first_name"
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
              <label htmlFor="last_name">Last Name</label>
              <input
                id="last_name"
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

          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              id="username"
              type="text"
              required
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
            />
            {fieldErrors.username && (
              <span className="field-error">{fieldErrors.username.join(', ')}</span>
            )}
          </div>

          {(isAdmin || isEditingSelf) && (
            <div className="form-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                required
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              />
              {fieldErrors.email && (
                <span className="field-error">{fieldErrors.email.join(', ')}</span>
              )}
            </div>
          )}

          {(isAdmin || isEditingSelf) && (
            <div className="form-group">
              <label htmlFor="date_of_birth">Date of Birth (must be in past)</label>
              <input
                id="date_of_birth"
                type="date"
                value={formData.date_of_birth || ''}
                onChange={(e) => setFormData({ ...formData, date_of_birth: e.target.value })}
              />
              {fieldErrors.date_of_birth && (
                <span className="field-error">{fieldErrors.date_of_birth.join(', ')}</span>
              )}
            </div>
          )}

          <div className="form-group">
            <label htmlFor="role">Role</label>
            <select
              id="role"
              value={formData.role}
              disabled={!isAdmin}
              onChange={(e) => setFormData({ ...formData, role: e.target.value as Role })}
              className={!isAdmin ? 'disabled-input' : ''}
            >
              <option value="member">member</option>
              <option value="admin">admin</option>
            </select>
            {!isAdmin && (
              <span className="form-help">Only administrators can modify roles.</span>
            )}
            {fieldErrors.role && (
              <span className="field-error">{fieldErrors.role.join(', ')}</span>
            )}
          </div>

          <div className="form-group">
            <label htmlFor="password">Change Password (leave blank to keep current)</label>
            <input
              id="password"
              type="password"
              placeholder="Minimum 8 characters"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            />
            {fieldErrors.password && (
              <span className="field-error">{fieldErrors.password.join(', ')}</span>
            )}
          </div>

          <div className="modal-actions">
            <button type="button" onClick={onClose} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={loading} className="btn btn-primary">
              {loading ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
