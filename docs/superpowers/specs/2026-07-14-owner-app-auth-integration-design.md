# Owner App Phone Authentication Integration Design

## Goal

Connect the existing Flutter owner login screen to the Spring Boot SMS-code APIs and add a unified backend login endpoint that automatically registers new owners, authenticates existing owners, and returns a 30-day JWT session.

## Scope

This feature applies only to the owner app. The worker login page remains unchanged until the backend supports `WORKER` authentication.

The backend keeps the existing endpoints:

- `POST /api/v1/auth/sms-codes`
- `POST /api/v1/auth/register`

It adds:

- `POST /api/v1/auth/login`

The Flutter owner app uses `sms-codes` and `login`. Users do not choose between registration and login: a verified new phone creates an owner account, while a verified existing owner phone opens a session.

## User Flow

1. The user enters a mainland China mobile number on the existing owner login page.
2. The app requests a code from `POST /api/v1/auth/sms-codes`.
3. In development, the returned simulated code is placed into the code field and the app explains that it was filled automatically. In environments where the response does not contain a code, the app reports that an SMS was sent.
4. The user submits the six-digit code.
5. The app calls `POST /api/v1/auth/login`.
6. The backend validates and consumes the code exactly once.
7. If no user exists, the backend creates an `ACTIVE` user with `OWNER`. If an active owner exists, it reuses that account.
8. The backend returns user data and a signed JWT.
9. The app stores the JWT in platform secure storage, updates owner state, and follows the existing onboarding/home routing rules.
10. Logging out clears the secure token and the local logged-in flag.

## Backend API

### Login request

`POST /api/v1/auth/login`

```json
{
  "phone": "16600000002",
  "code": "256438"
}
```

### Login response

The endpoint uses the existing `ApiResponse` envelope. Its `data` value is:

```json
{
  "accessToken": "eyJ...",
  "tokenType": "Bearer",
  "expiresInSeconds": 2592000,
  "user": {
    "id": "de706265-f219-4431-9c97-0308100e55f0",
    "phone": "16600000002",
    "status": "ACTIVE",
    "roles": ["OWNER"]
  }
}
```

The login operation is transactional. Successful verification consumes the code before returning. Concurrent reuse cannot create multiple users or sessions from one code.

## Account Rules

- A missing phone is automatically registered as an `ACTIVE` user with `OWNER`.
- An existing `ACTIVE` user with `OWNER` may log in.
- A `DISABLED` user receives `ACCOUNT_DISABLED` and no token.
- An existing user without `OWNER` receives `OWNER_ACCESS_DENIED` and no token.
- Duplicate-account races rely on the unique phone constraint and are resolved by loading the winning user before completing login.
- The existing `/register` behavior remains available and unchanged for compatibility.

## JWT Design

JWTs use the existing JJWT dependencies and HMAC signing. The signing secret comes from `AUTH_JWT_SECRET`; no production secret is committed. Development and test profiles use explicit non-production defaults of at least 32 bytes.

Each token contains:

- `sub`: user UUID;
- `phone`: normalized phone number;
- `roles`: role names;
- `iat`: issue time;
- `exp`: issue time plus 30 days.

The response declares `tokenType` as `Bearer` and `expiresInSeconds` as `2592000`. This first version does not issue refresh tokens or persist token plaintext. Future protected API calls send `Authorization: Bearer <token>`.

## Flutter Components

### `AuthApiClient`

Owns JSON HTTP calls for SMS issuance and login. It parses the shared backend envelope and maps backend error codes into typed app exceptions. The base URL comes from:

```text
--dart-define=API_BASE_URL=<url>
```

Defaults and launch guidance are:

- iOS Simulator and macOS: `http://localhost:8080`;
- Android Emulator: `http://10.0.2.2:8080`;
- physical devices: the development Mac's reachable LAN address.

No production host is hard-coded.

### `AuthSessionStore`

Uses `flutter_secure_storage` so iOS stores the token in Keychain and Android stores it through platform-backed encrypted storage. It provides read, write, and clear operations for the JWT and authenticated user ID.

### `OwnerAppState`

The existing state remains responsible for local profile and route state. After a backend login succeeds, it records the phone and logged-in state. Logout clears secure session data as well as local state. Secure-storage failures prevent claiming a successful login, rather than silently continuing without a token.

### `LoginPage`

The existing visual design stays intact. The page replaces simulated delays with real async operations, disables duplicate submissions while requests are active, starts the countdown only after successful issuance, and always clears loading state after success or failure.

## Error Handling

The app presents concise Chinese messages for:

- `SMS_RATE_LIMITED`, including the retry guidance returned by the backend;
- `SMS_CODE_INVALID`;
- `SMS_CODE_EXPIRED`;
- `SMS_CODE_ATTEMPTS_EXCEEDED`;
- `ACCOUNT_DISABLED`;
- `OWNER_ACCESS_DENIED`;
- invalid request fields;
- connection timeout or unreachable server;
- unexpected server responses.

The app must not mark the user logged in after any failed network, verification, token-storage, or state-persistence operation. Tokens and verification codes are excluded from logs.

## Dependencies and Configuration

The Flutter app adds an HTTP client package and `flutter_secure_storage`. Platform manifests receive only the changes required for local HTTP development and secure storage. Production transport must use HTTPS; development cleartext exceptions must be scoped to local development instead of globally weakening release security.

The Spring Boot app adds JWT configuration properties but no new library, because JJWT is already present.

## Testing

Backend tests cover:

- new phone auto-registration and login;
- existing active owner login;
- one-time code consumption;
- invalid, expired, and five-times-wrong codes;
- disabled users and users without `OWNER`;
- duplicate-account races;
- JWT signature, subject, phone, roles, issue time, and 30-day expiration;
- OpenAPI exposure of `/api/v1/auth/login`;
- unchanged `/register` behavior.

Flutter tests cover:

- SMS request success and development auto-fill;
- countdown starting only after success;
- unified login request and response parsing;
- backend error-code messages;
- network failure without false login;
- secure token save on success;
- token clearing on logout;
- existing owner route behavior after login;
- all existing widget and state tests.

The complete Maven suite runs against Docker-backed MySQL. Flutter unit/widget tests run with fake API and session-store implementations, so tests do not depend on a live backend.

## Acceptance Criteria

With the backend running locally, the owner Flutter app can request a simulated code, automatically fill it in development, log in with an existing active owner or automatically create a new owner, securely retain the returned 30-day JWT, and clear it on logout. Failed or rate-limited requests never create a false local login. The login endpoint appears in Swagger, and the complete backend and Flutter test suites pass.
