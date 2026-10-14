import { useAuth } from '../context';
import { LogOut, Users } from 'lucide-react';

interface NavbarProps {
  onOpenProfile?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ onOpenProfile }) => {
  const { user, isAdmin, logout } = useAuth();

  return (
    <header className="navbar">
      <div className="navbar-container">
        <div className="navbar-brand">
          <div className="brand-logo">
            <Users size={20} />
          </div>
          <h1 className="brand-title">User Service</h1>
        </div>

        {user && (
          <div className="navbar-user">
            <div
              className={`user-profile ${onOpenProfile ? 'user-profile-clickable' : ''}`}
              onClick={onOpenProfile}
              role={onOpenProfile ? 'button' : undefined}
              tabIndex={onOpenProfile ? 0 : undefined}
              onKeyDown={(e) => {
                if (onOpenProfile && (e.key === 'Enter' || e.key === ' ')) {
                  e.preventDefault();
                  onOpenProfile();
                }
              }}
              title={onOpenProfile ? 'Click to edit your profile' : undefined}
            >
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
