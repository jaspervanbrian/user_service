import { useAuth } from '../context';
import { LogOut } from 'lucide-react';

export const Navbar: React.FC = () => {
  const { user, isAdmin, logout } = useAuth();

  return (
    <header className="navbar">
      <div className="navbar-container">
        <div className="navbar-brand">
          <div className="brand-logo">US</div>
          <h1 className="brand-title">User Service</h1>
        </div>

        {user && (
          <div className="navbar-user">
            <div className="user-profile">
              <div className="user-avatar">
                {user.first_name[0]}
                {user.last_name[0]}
              </div>
              <div className="user-details">
                <span className="user-name">
                  {user.first_name} {user.last_name}
                </span>
                <span className="user-meta">
                  @{user.username} &bull;{' '}
                  <span className={`role-badge ${isAdmin ? 'role-admin' : 'role-member'}`}>
                    {user.role}
                  </span>
                </span>
              </div>
            </div>

            <button onClick={logout} className="btn btn-secondary btn-sm" title="Log out">
              <LogOut size={14} style={{ marginRight: '6px' }} />
              Log out
            </button>
          </div>
        )}
      </div>
    </header>
  );
};
