# iOS QA Checklist (StoryMaps)

## Auth (Firebase)

- Launch app → see “Checking your session…” briefly, then auth screen when signed out
- Email/password:
  - Sign up (valid email, 6+ char password)
  - Sign out
  - Sign in
  - Password reset email sends (verify received)
- Google Sign-In:
  - Sign in with Google
  - Sign out
  - Relaunch app → should remain signed out

## Maps / Places / Directions

- Autocomplete for Start and End works (Places UI shows suggestions)
- Selecting Start/End drops pins and focuses map
- “Create story” triggers route calculation
- Route preview renders polyline and shows distance + duration

## Story generation (Node `/api-proxy`)

- After route confirm, app shows loading messages (outline → first chapter → audio)
- First chapter text appears and audio plays
- Let it play while watching the “buffering” indicator: additional segments appear over time
- Next/previous segment buttons switch chapters and audio

## Failure modes

- Missing `Secrets.plist` → app should still run and show clear errors on route calc / story generation
- Invalid Directions API key → route calc shows an error message
- Server URL wrong/unreachable → story generation shows an error message

