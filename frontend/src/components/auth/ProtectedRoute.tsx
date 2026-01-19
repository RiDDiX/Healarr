import { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { getAuthStatus } from '../../lib/api';
import { useWebSocket } from '../../contexts/WebSocketProvider';

interface ProtectedRouteProps {
    children: React.ReactNode;
}

const ProtectedRoute = ({ children }: ProtectedRouteProps) => {
    const [isChecking, setIsChecking] = useState(true);
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [needsSetup, setNeedsSetup] = useState(false);
    const { reconnect } = useWebSocket();

    useEffect(() => {
        const checkAuth = async () => {
            const token = localStorage.getItem('healarr_token');
            
            if (!token) {
                // No token - check if setup is needed
                try {
                    const status = await getAuthStatus();
                    setNeedsSetup(!status.is_setup);
                } catch {
                    // If we can't check status, assume setup needed
                    setNeedsSetup(true);
                }
                setIsAuthenticated(false);
                setIsChecking(false);
                return;
            }

            // Have a token - verify it's still valid by checking auth status
            try {
                const status = await getAuthStatus();
                if (!status.is_setup) {
                    // Password was reset, need to set up again
                    localStorage.removeItem('healarr_token');
                    setNeedsSetup(true);
                    setIsAuthenticated(false);
                } else {
                    setIsAuthenticated(true);
                    // Now that we've verified the token is valid, connect WebSocket
                    // This ensures we don't try to connect with stale tokens
                    reconnect();
                }
            } catch {
                // Token might be invalid
                localStorage.removeItem('healarr_token');
                setIsAuthenticated(false);
            }
            
            setIsChecking(false);
        };

        checkAuth();
        // Only check auth on initial mount, not on every navigation
        // Navigation within the app doesn't need re-authentication
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    if (isChecking) {
        return (
            <div className="min-h-screen bg-slate-100 dark:bg-slate-950 flex items-center justify-center">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-500"></div>
            </div>
        );
    }

    if (!isAuthenticated) {
        // Redirect to login
        return <Navigate to="/login" state={{ needsSetup }} replace />;
    }

    return <>{children}</>;
};

export default ProtectedRoute;
