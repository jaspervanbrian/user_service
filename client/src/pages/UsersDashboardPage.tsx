import React, { useState, useEffect, useCallback } from 'react';
import type { User, PaginationMeta } from '../types';
import { api, ApiException } from '../api';
import { useAuth } from '../context';
import { Navbar } from '../components/Navbar';
import { EditUserModal } from '../components/EditUserModal';
import { CreateUserModal } from '../components/CreateUserModal';
import { Toast, type ToastMessage } from '../components/Toast';

export const UsersDashboardPage: React.FC = () => {
  const { token, user: currentUser, isAdmin, logout } = useAuth();

  const [users, setUsers] = useState<User[]>([]);
  const [pagination, setPagination] = useState<PaginationMeta>({
    next_cursor: null,
    has_next_page: false,
    limit: 10,
    page: 1,
  });

  const [currentPage, setCurrentPage] = useState(1);
  const [pageJumpInput, setPageJumpInput] = useState('1');
  const [pageSize, setPageSize] = useState(10);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastMessage | null>(null);

  // History map of page number -> starting cursor
  const [cursorHistory, setCursorHistory] = useState<Record<number, string | null>>({
    1: null,
  });

  // Modal states
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  const loadUsers = useCallback(
    async (opts: { cursor?: string | null; page?: number | null; limit?: number }) => {
      if (!token) return;

      setLoading(true);
      setError(null);

      try {
        const response = await api.getUsers(token, {
          cursor: opts.cursor,
          page: opts.page,
          limit: opts.limit || pageSize,
        });

        setUsers(response.users);
        setPagination(response.pagination);

        const targetPage = opts.page || currentPage;
        setCurrentPage(targetPage);
        setPageJumpInput(targetPage.toString());

        // Cache the next page cursor if available
        if (response.pagination.next_cursor) {
          setCursorHistory((prev) => ({
            ...prev,
            [targetPage + 1]: response.pagination.next_cursor,
          }));
        }
      } catch (err) {
        if (err instanceof ApiException) {
          if (err.status === 401) {
            logout();
            return;
          }
          setError(err.message);
        } else {
          setError('Failed to fetch users. Please check server connection.');
        }
      } finally {
        setLoading(false);
      }
    },
    [token, pageSize, currentPage, logout]
  );

  // Initial load or page size change
  useEffect(() => {
    loadUsers({ cursor: null, page: 1, limit: pageSize });
  }, [pageSize]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleNextPage = () => {
    if (!pagination.has_next_page || !pagination.next_cursor) return;
    const nextPage = currentPage + 1;
    loadUsers({ cursor: pagination.next_cursor, page: nextPage, limit: pageSize });
  };

  const handlePrevPage = () => {
    if (currentPage <= 1) return;
    const prevPage = currentPage - 1;
    const cursor = cursorHistory[prevPage];
    // If we have the cursor cached, use it; otherwise use page offset
    if (cursor !== undefined) {
      loadUsers({ cursor, page: prevPage, limit: pageSize });
    } else {
      loadUsers({ page: prevPage, limit: pageSize });
    }
  };

  const handlePageJump = (e: React.FormEvent) => {
    e.preventDefault();
    const target = parseInt(pageJumpInput, 10);
    if (isNaN(target) || target < 1) {
      setPageJumpInput(currentPage.toString());
      return;
    }

    if (target === currentPage) return;

    // Check if we have the cursor for this target page
    const cachedCursor = cursorHistory[target];
    if (cachedCursor !== undefined) {
      loadUsers({ cursor: cachedCursor, page: target, limit: pageSize });
    } else {
      loadUsers({ page: target, limit: pageSize });
    }
  };

  const handleUserUpdated = (updatedUser: User) => {
    setUsers((prev) => prev.map((u) => (u.id === updatedUser.id ? updatedUser : u)));
    setEditingUser(null);
    setToast({ type: 'success', message: `User @${updatedUser.username} updated successfully!` });
  };

  const handleUserCreated = (newUser: User) => {
    setIsCreateModalOpen(false);
    setToast({ type: 'success', message: `User @${newUser.username} created successfully!` });
    // Reload first page to show newly created record
    loadUsers({ page: 1, limit: pageSize });
  };

  return (
    <div className="dashboard-layout">
      <Navbar />

      <Toast toast={toast} onClose={() => setToast(null)} />

      <main className="dashboard-content">
        <div className="dashboard-header">
          <h2 className="page-title">Users Directory</h2>

          {isAdmin && (
            <button
              onClick={() => setIsCreateModalOpen(true)}
              className="btn btn-primary"
            >
              + Create New User
            </button>
          )}
        </div>

        {/* Role & Visibility Banner */}
        <div className={`policy-banner ${isAdmin ? 'banner-admin' : 'banner-member'}`}>
          <div className="policy-banner-icon">{isAdmin ? '🛡️' : '🔒'}</div>
          <div>
            <strong>{isAdmin ? 'Administrator Access' : 'Standard Member Access'}</strong>
            <p>
              {isAdmin
                ? 'You have elevated privileges. You can view all user emails, dates of birth, create new accounts, and promote/demote user roles.'
                : 'Role-Based Access Control (RBAC): Email and Date of Birth fields are strictly private and masked for other users. You can edit your own profile details.'}
            </p>
          </div>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {/* Users Table */}
        <div className="card table-card">
          <div className="table-responsive">
            <table className="users-table">
              <thead>
                <tr>
                  <th style={{ width: '60px' }}>ID</th>
                  <th>Username</th>
                  <th>Full Name</th>
                  <th>Role</th>
                  <th>Email</th>
                  <th>Date of Birth</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading && users.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="table-empty">
                      Loading users directory...
                    </td>
                  </tr>
                ) : users.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="table-empty">
                      No users found.
                    </td>
                  </tr>
                ) : (
                  users.map((u) => {
                    const isSelf = currentUser?.id === u.id;
                    const canEdit = isAdmin || isSelf;

                    return (
                      <tr key={u.id} className={isSelf ? 'row-self' : ''}>
                        <td className="text-muted">#{u.id}</td>
                        <td>
                          <strong>@{u.username}</strong>
                          {isSelf && <span className="badge badge-self">You</span>}
                        </td>
                        <td>
                          {u.first_name} {u.last_name}
                        </td>
                        <td>
                          <span
                            className={`role-badge ${
                              u.role === 'admin' ? 'role-admin' : 'role-member'
                            }`}
                          >
                            {u.role}
                          </span>
                        </td>
                        <td>
                          {u.email ? (
                            <span className="field-value">{u.email}</span>
                          ) : (
                            <span className="field-restricted" title="Only visible to Admins or Self">
                              🔒 Restricted
                            </span>
                          )}
                        </td>
                        <td>
                          {u.date_of_birth ? (
                            <span className="field-value">{u.date_of_birth}</span>
                          ) : u.date_of_birth === null ? (
                            <span className="text-muted">Not provided</span>
                          ) : (
                            <span className="field-restricted" title="Only visible to Admins or Self">
                              🔒 Restricted
                            </span>
                          )}
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          {canEdit ? (
                            <button
                              onClick={() => setEditingUser(u)}
                              className="btn btn-secondary btn-sm"
                            >
                              Edit
                            </button>
                          ) : (
                            <span className="text-muted" style={{ fontSize: '0.8rem' }}>
                              Read-only
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Custom Pagination Footer with direct page input */}
          <div className="pagination-footer">
            <div className="pagination-info">
              <span>
                Showing <strong>{users.length}</strong> records per page &bull; Page{' '}
                <strong>{currentPage}</strong>
              </span>

              <div className="page-size-selector">
                <label htmlFor="page_size">Per page:</label>
                <select
                  id="page_size"
                  value={pageSize}
                  onChange={(e) => setPageSize(Number(e.target.value))}
                >
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                </select>
              </div>
            </div>

            <div className="pagination-controls">
              <button
                type="button"
                onClick={handlePrevPage}
                disabled={currentPage <= 1 || loading}
                className="btn btn-secondary btn-sm"
              >
                &larr; Prev
              </button>

              <form onSubmit={handlePageJump} className="page-jump-form">
                <span>Page</span>
                <input
                  type="number"
                  min={1}
                  value={pageJumpInput}
                  onChange={(e) => setPageJumpInput(e.target.value)}
                  className="page-jump-input"
                  title="Enter page number and press Jump or Enter"
                />
                <button type="submit" disabled={loading} className="btn btn-outline btn-sm">
                  Jump
                </button>
              </form>

              <button
                type="button"
                onClick={handleNextPage}
                disabled={!pagination.has_next_page || loading}
                className="btn btn-secondary btn-sm"
              >
                Next &rarr;
              </button>
            </div>
          </div>
        </div>
      </main>

      {/* Modals */}
      {editingUser && (
        <EditUserModal
          user={editingUser}
          onClose={() => setEditingUser(null)}
          onSuccess={handleUserUpdated}
        />
      )}

      {isCreateModalOpen && (
        <CreateUserModal
          onClose={() => setIsCreateModalOpen(false)}
          onSuccess={handleUserCreated}
        />
      )}
    </div>
  );
};
