/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React from 'react';

interface Props {
    children: React.ReactNode;
}

interface State {
    hasError: boolean;
}

/**
 * Top-level error boundary: a render-time throw anywhere in the tree shows a
 * recoverable message instead of a blank page.
 */
class ErrorBoundary extends React.Component<Props, State> {
    state: State = { hasError: false };

    static getDerivedStateFromError(): State {
        return { hasError: true };
    }

    componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
        console.error('Unhandled render error:', error, errorInfo);
    }

    render() {
        if (this.state.hasError) {
            return (
                <div className="min-h-screen bg-editorial-100 flex items-center justify-center p-6">
                    <div className="bg-white p-8 rounded-[2rem] shadow-xl max-w-md text-center space-y-4 border border-stone-100">
                        <h1 className="text-2xl font-display text-editorial-900">Something went wrong.</h1>
                        <p className="text-stone-600">An unexpected error interrupted the app.</p>
                        <button
                            onClick={() => window.location.reload()}
                            className="bg-editorial-900 text-white px-6 py-3 rounded-full font-semibold text-sm hover:bg-stone-800 transition-all"
                        >
                            Reload the app
                        </button>
                    </div>
                </div>
            );
        }
        return this.props.children;
    }
}

export default ErrorBoundary;
