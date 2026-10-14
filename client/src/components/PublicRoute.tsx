import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context';

export const PublicRoute: React.FC = () => {
  const { isAuthenticated } = useAuth();

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
};
