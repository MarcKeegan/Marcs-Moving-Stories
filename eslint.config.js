import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';

export default tseslint.config(
  {
    ignores: ['dist/**', 'node_modules/**', 'server/node_modules/**', 'ios/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      globals: { ...globals.browser, google: 'readonly' },
    },
    plugins: {
      'react-hooks': reactHooks,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // Advisory React Compiler rules: the imperative audio engine and Maps
      // widget integration legitimately set state from effects. Keep them
      // visible as warnings without failing the build.
      'react-hooks/set-state-in-effect': 'warn',
      'react-hooks/immutability': 'warn',
    },
  },
  {
    // Express proxy server: CommonJS + Node globals
    files: ['server/*.js'],
    languageOptions: {
      sourceType: 'commonjs',
      globals: { ...globals.node },
    },
    rules: {
      '@typescript-eslint/no-require-imports': 'off',
    },
  },
  {
    // Browser scripts served by the proxy (service worker + WS interceptor)
    files: ['server/public/*.js'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.serviceworker },
    },
  }
);
