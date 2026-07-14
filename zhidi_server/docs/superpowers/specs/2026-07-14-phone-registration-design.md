# Phone Registration With Simulated SMS Design

## Goal

Add a development-safe phone registration flow to the Zhidi Spring Boot API. The flow uses simulated SMS verification codes, enforces realistic anti-abuse limits without sending paid messages, and persists all verification state in MySQL.

## Scope

This feature provides two public endpoints:

- `POST /api/v1/auth/sms-codes` requests a simulated verification code.
- `POST /api/v1/auth/register` verifies the code and creates an owner account.

The feature does not send real SMS messages, accept passwords, or issue login tokens. A future SMS provider may replace the simulated sender without changing the registration flow.

## API Design

### Request a verification code

`POST /api/v1/auth/sms-codes`

Request:

```json
{
  "phone": "13800138000"
}
```

Successful development response data:

```json
{
  "code": "123456",
  "expiresInSeconds": 300,
  "retryAfterSeconds": 60
}
```

The response uses the existing `ApiResponse` envelope. The simulated code is returned only while the `dev` profile is active. No production profile may expose a verification code in an API response.

### Register an account

`POST /api/v1/auth/register`

Request:

```json
{
  "phone": "13800138000",
  "code": "123456"
}
```

Successful response data contains the new user's ID, normalized phone number, `ACTIVE` status, and roles. A newly registered user receives the `OWNER` role. Registration does not issue a session or authentication token.

## Components and Boundaries

The auth web layer validates request shapes and maps service results into the existing `ApiResponse` envelope. A registration service coordinates code issuance, code verification, user uniqueness checks, and user creation.

Verification-code persistence is isolated behind a repository. A code generator produces six-digit codes, while a code hasher ensures plaintext codes are never stored in MySQL. A simulated SMS sender exposes the code to the development response; its interface is the replacement point for a real provider later.

The implementation uses MySQL rather than process memory so expiration, attempt counts, and rate limits survive application restarts. It does not add Redis or an external messaging dependency.

## Persistence

Add a Flyway migration for `sms_verification_codes`. Each record stores:

- normalized phone number;
- verification-code hash, never plaintext;
- requester IP address;
- creation and expiration timestamps;
- failed verification attempt count;
- used or invalidated state;
- the timestamp at which the record was consumed or invalidated, when applicable.

Indexes must support recent-send counts by phone and IP and lookup of the latest active code by phone. Issuing a new code invalidates every older active code for that phone.

Operations that change code state must be transactional. Concurrent requests must not allow the same verification code to register more than one user, and the database's unique phone constraint remains the final protection against duplicate accounts.

## Anti-Abuse Rules

Before issuing a code, the service applies all of these limits:

- the same phone may request one code per 60 seconds;
- the same phone may request at most 5 codes in a rolling hour;
- the same phone may request at most 10 codes in a rolling 24 hours;
- the same IP may request at most 20 codes in a rolling hour;
- the same IP may request at most 50 codes in a rolling 24 hours.

A code expires 5 minutes after issuance. A wrong code increments the failed-attempt count. Five failed attempts invalidate the code. Successful verification consumes it immediately, so it cannot be reused.

Rate-limited responses use HTTP 429 and code `SMS_RATE_LIMITED`. Where applicable, the response communicates how long the caller should wait before retrying.

## Validation and Errors

Phone numbers use the existing mainland mobile-number rule and are normalized before lookup. Verification codes must contain exactly six decimal digits.

The feature uses these business error codes:

- `SMS_RATE_LIMITED` for any phone or IP send limit;
- `SMS_CODE_INVALID` for an incorrect code before the attempt limit;
- `SMS_CODE_EXPIRED` for an expired code;
- `SMS_CODE_ATTEMPTS_EXCEEDED` after five failed attempts;
- `PHONE_ALREADY_REGISTERED` when the normalized phone already belongs to a user;
- `VALIDATION_ERROR` for malformed phone numbers or request fields.

Errors use the existing `ApiResponse` envelope and include the request trace ID. Unexpected internal details and code hashes are never returned.

## Security and Environment Behavior

Both endpoints are public because they run before authentication. The simulated sender is enabled only for local development. Verification codes are hashed at rest and excluded from ordinary logs. Request IP extraction uses the direct remote address for this local version; trusting proxy-forwarded headers is deferred until a trusted proxy configuration exists.

## Testing

Service and API tests cover:

- successful code issuance and owner registration;
- development-only exposure of the simulated code;
- phone cooldown, hourly limit, and daily limit;
- IP hourly and daily limits;
- expiration after five minutes;
- invalid-code attempt counting and invalidation on the fifth failure;
- invalidation of old codes when a new code is issued;
- one-time consumption and protection against concurrent reuse;
- duplicate phone registration;
- invalid phone and code formats;
- both operations appearing in the generated OpenAPI specification.

Database integration tests use the existing Testcontainers MySQL setup so migrations, constraints, indexes, and transactional behavior are exercised against MySQL rather than an in-memory substitute.

## Acceptance Criteria

With the development profile active, a caller can request a simulated code and use it once to register an `ACTIVE` user with the `OWNER` role. Every agreed phone and IP rate limit is enforced, invalid and expired codes cannot create users, no plaintext code is persisted, and Swagger UI displays both auth operations. The complete Maven test suite passes against Docker-backed MySQL.
