import React, { useEffect, useState } from 'react';
import { auth } from '../firebase';

export const DebugStatus = () => {
    const [token, setToken] = useState<string | null>(null);
    const [env, setEnv] = useState<any>({});

    useEffect(() => {
        // Check Env
        const runtimeEnv = (window as any).__ENV__;
        setEnv(runtimeEnv || { error: "No __ENV__ found" });

        // Check Auth
        const checkToken = async () => {
            const t = await auth.currentUser?.getIdToken();
            setToken(t ? "Token Present (" + t.substring(0, 5) + "...)" : "No Token");
        };
        const timer = setInterval(checkToken, 2000);
        checkToken();
        return () => clearInterval(timer);
    }, []);

    return (
        <div className="fixed bottom-4 left-4 bg-black/80 text-white p-4 rounded-lg text-xs font-mono z-50 pointer-events-none max-w-sm">
            <h3 className="font-bold text-yellow-400 mb-2">DEBUG STATUS</h3>
            <div>User: {auth.currentUser ? auth.currentUser.email : "Logged Out"}</div>
            <div>Token: {token}</div>
            <div className="mt-2 border-t border-gray-600 pt-2">
                <div className="font-bold text-blue-300">Environment:</div>
                <pre>{JSON.stringify(env, null, 2)}</pre>
            </div>
        </div>
    );
};
