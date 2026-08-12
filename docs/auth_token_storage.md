# Auth Token Storage Plan

Notes for implementing access/refresh token handling. Not yet implemented.

## Decisions

- **`UserModel` stays profile-only.** No `accessToken`/`refreshToken` fields on it —
  it mirrors the Firestore user doc and shouldn't carry auth credentials. The existing
  `token` field on `UserModel` is the FCM push token, unrelated to auth session tokens.
- **Both `accessToken` and `refreshToken` are persisted in `flutter_secure_storage`**
  (Keychain on iOS, Keystore/EncryptedSharedPreferences on Android). Do not put the
  access token in `SharedPreferences` — it's plaintext at rest and readable via a
  rooted device, jailbreak, or `adb backup` on a debuggable build. Short expiry
  reduces blast radius, it doesn't remove the risk.
- **Access token is also cached in memory** (a field on the auth
  singleton/repository) to avoid an async secure-storage read on every request.
  Load it once at app startup, update it on every refresh. This solves the
  "accessed frequently" concern without weakening where it lives at rest.

## Planned structure

- `AuthTokens` model: `{ accessToken, refreshToken, expiresAt }`.
- `TokenStorage` (or `AuthLocalDataSource`): thin wrapper around
  `flutter_secure_storage` with `save`, `read`, `clear`. Only place that touches
  secure storage directly.
- `AuthRepository`: owns the in-memory access-token cache, exposes it to the
  HTTP client, and handles refresh flow (call refresh endpoint with refresh
  token, persist + cache the new access token).
- HTTP interceptor (Dio or equivalent): attaches `Authorization` header from the
  in-memory access token; on 401, triggers `AuthRepository` refresh and retries.
