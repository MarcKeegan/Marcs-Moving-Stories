/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React, { useState } from 'react';
import { useAuth } from '../AuthContext';

const LOGO_URL = 'https://res.cloudinary.com/marcusdiablo/image/upload/v1768537734/storymaps_sbmb9p.png';

type AuthMode = 'login' | 'signup' | 'reset';

const AuthScreen: React.FC = () => {
    const {
        error: authError,
        loginWithGoogle,
        loginWithEmail,
        registerWithEmail,
        resetPassword,
    } = useAuth();

    const [authMode, setAuthMode] = useState<AuthMode>('login');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [localAuthError, setLocalAuthError] = useState<string | null>(null);
    const [resetMessage, setResetMessage] = useState<string | null>(null);

    const handleEmailSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLocalAuthError(null);
        setResetMessage(null);

        if (authMode === 'signup') {
            if (password !== confirmPassword) {
                setLocalAuthError("Passwords don't match");
                return;
            }
            if (password.length < 6) {
                setLocalAuthError('Password should be at least 6 characters');
                return;
            }
            await registerWithEmail(email, password);
        } else if (authMode === 'login') {
            await loginWithEmail(email, password);
        } else if (authMode === 'reset') {
            if (!email) {
                setLocalAuthError('Enter your email to reset your password');
                return;
            }
            await resetPassword(email);
            setResetMessage('If an account exists for that email, a reset link has been sent.');
        }
    };

    return (
        <div className="min-h-screen bg-editorial-100 flex items-center justify-center px-6">
            <div className="bg-white p-8 md:p-10 rounded-[2rem] shadow-xl max-w-md w-full space-y-6 border border-stone-100">
                <div className="flex justify-center">
                    <img
                        src={LOGO_URL}
                        alt="StoryMaps"
                        className="h-16 w-auto"
                        loading="eager"
                        decoding="async"
                    />
                </div>
                <h1 className="text-3xl font-display text-editorial-900 text-center">
                    Welcome to StoryMaps.
                </h1>
                <p className="text-stone-500 text-center">
                    Sign in to create and listen to personalized journey stories.
                </p>

                <div className="flex rounded-full bg-stone-100 p-1 text-sm font-medium">
                    <button
                        type="button"
                        onClick={() => setAuthMode('login')}
                        className={`flex-1 py-2 rounded-full transition-all ${authMode === 'login'
                            ? 'bg-white text-editorial-900 shadow-sm'
                            : 'text-stone-500'
                            }`}
                    >
                        Sign in
                    </button>
                    <button
                        type="button"
                        onClick={() => setAuthMode('signup')}
                        className={`flex-1 py-2 rounded-full transition-all ${authMode === 'signup'
                            ? 'bg-white text-editorial-900 shadow-sm'
                            : 'text-stone-500'
                            }`}
                    >
                        Sign up
                    </button>
                </div>

                <form onSubmit={handleEmailSubmit} className="space-y-4">
                    <div className="space-y-1">
                        <label htmlFor="auth-email" className="text-sm font-medium text-stone-600">Email</label>
                        <input
                            id="auth-email"
                            type="email"
                            autoComplete="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                            required
                        />
                    </div>

                    {authMode !== 'reset' && (
                        <>
                            <div className="space-y-1">
                                <label htmlFor="auth-password" className="text-sm font-medium text-stone-600">Password</label>
                                <input
                                    id="auth-password"
                                    type="password"
                                    autoComplete={authMode === 'signup' ? 'new-password' : 'current-password'}
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                                    required
                                />
                            </div>
                            {authMode === 'signup' && (
                                <div className="space-y-1">
                                    <label htmlFor="auth-confirm-password" className="text-sm font-medium text-stone-600">Confirm password</label>
                                    <input
                                        id="auth-confirm-password"
                                        type="password"
                                        autoComplete="new-password"
                                        value={confirmPassword}
                                        onChange={(e) => setConfirmPassword(e.target.value)}
                                        className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                                        required
                                    />
                                </div>
                            )}
                        </>
                    )}

                    {(localAuthError || authError) && (
                        <p role="alert" className="text-xs text-red-600 bg-red-50 px-3 py-2 rounded-lg">
                            {localAuthError || authError}
                        </p>
                    )}

                    {resetMessage && (
                        <p role="status" className="text-xs text-green-700 bg-green-50 px-3 py-2 rounded-lg">
                            {resetMessage}
                        </p>
                    )}

                    <button
                        type="submit"
                        className="w-full bg-editorial-900 text-white py-3 rounded-full font-semibold text-sm hover:bg-stone-800 transition-all"
                    >
                        {authMode === 'signup'
                            ? 'Create account'
                            : authMode === 'reset'
                                ? 'Send reset link'
                                : 'Sign in with email'}
                    </button>

                    {authMode === 'login' && (
                        <button
                            type="button"
                            onClick={() => setAuthMode('reset')}
                            className="block w-full text-xs text-center text-stone-500 hover:text-editorial-900 mt-1 underline"
                        >
                            Forgot password?
                        </button>
                    )}
                    {authMode === 'reset' && (
                        <button
                            type="button"
                            onClick={() => setAuthMode('login')}
                            className="block w-full text-xs text-center text-stone-500 hover:text-editorial-900 mt-1 underline"
                        >
                            Back to sign in
                        </button>
                    )}
                </form>

                <div className="flex items-center gap-3">
                    <div className="h-px bg-stone-200 flex-1" />
                    <span className="text-xs text-stone-400 uppercase tracking-widest">or</span>
                    <div className="h-px bg-stone-200 flex-1" />
                </div>

                <button
                    onClick={loginWithGoogle}
                    className="w-full border border-stone-200 bg-white text-editorial-900 py-3 rounded-full font-semibold text-sm hover:bg-stone-50 transition-all"
                >
                    Continue with Google
                </button>
            </div>
        </div>
    );
};

export default AuthScreen;
