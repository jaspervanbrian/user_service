# User Service API

A Rails 8 API-only service for managing users, secured with asymmetric RS256 JWT authentication and attribute-based/role-based authorization (Pundit).

---

## Architecture & Design Highlights

### 1. User Domain Model
- **Username:** Preserves casing for display (`JDoe`), but enforces case-insensitive uniqueness at both the model validation layer and the database engine layer via an expression index (`lower(username)`). Disallows `@` to ensure logins are never ambiguous.
- **Password:** Uses BCrypt (`has_secure_password`) with an 8-character minimum.
- **Date of Birth:** Optional (nullable). When provided, validates that it must be strictly in the past.
- **Role:** Enum (`member: 0`, `admin: 1`), defaulting to `member`.

### 2. Field Visibility & Authorization (RBAC + ABAC)
- **Private Fields:** `email` and `date_of_birth` are classified as sensitive PII.
- **Visibility Rules:** Only **admins** or the **user viewing their own profile** can view private fields.
- **Serialization ([UserSerializer](app/serializers/user_serializer.rb)):** Unauthorized viewers see private field keys completely omitted from the JSON payload (rather than sent as `null`), so clients can clearly distinguish between hidden fields and an unset date of birth.
- **Clean JWT Payload:** The JWT carries **no PII** (only `sub` and `role`).

### 3. Asymmetric JWT Authentication (RS256)
- **Token Signing:** Tokens are signed using an RSA 2048-bit private key.
- **Deterministic Key ID (`kid`):** Derived deterministically from the public key using RFC 7638 JWK thumbprint (`JWT::JWK.new(key).kid`), ensuring zero-config consistency between token headers and JWKS.
- **Public JWKS Endpoint:** `GET /.well-known/jwks.json` serves the public key set for token verification.
- **Swappable Verifier Seam (`Auth.verifier`):**
  - **Local (Current):** `Auth::Verifiers::Local` verifies token signatures and standard claims against `Auth.key_set.to_jwks`.
  - **Gateway (Future):** `Auth::Verifiers::Gateway` can be swapped via `AUTH_VERIFIER=gateway` to trust identity headers forwarded by an API Gateway (e.g. AWS API Gateway HTTP API or Kong) that verifies the JWT at the edge.
- **Zero-Downtime Key Rotation:** `Auth::KeySet` accepts previous public/private keys to verify active in-flight tokens while a newly rotated key signs new logins.

---

## Getting Started

### Prerequisites
- **Ruby:** 4.0+ (managed via `mise` or your preferred Ruby version manager)
- **SQLite3:** (Runs in WAL mode with `synchronous = NORMAL`)

### 1. Install Dependencies
```sh
bundle install
```

### 2. Database Setup & Seeds
```sh
bin/rails db:setup
# Or manually:
bin/rails db:migrate
bin/rails db:seed
```

### 3. Configure JWT Signing Key
You can configure the RSA private key using either of the following options:

#### Option A: Using OpenSSL + Rails Encrypted Credentials
1. Generate an RSA 2048-bit private key:
   ```sh
   openssl genrsa 2048
   ```
2. Open credentials in your editor:
   ```sh
   bin/rails credentials:edit
   ```
3. Add the issuer and private key:
   ```yaml
   issuer: http://localhost:3000
   private_key: |
     -----BEGIN RSA PRIVATE KEY-----
     ...
     -----END RSA PRIVATE KEY-----
   ```

#### OR Option B: Using the CLI Key Generator Script
Run the helper script to generate a key and format it for `.env` or credentials:
```sh
bin/generate-jwt-key
```
You can then paste `JWT_PRIVATE_KEY` directly into your `.env` or environment configuration.

---

## Running the Application

Start the Puma API server:
```sh
bin/rails server
```
The server will run on `http://localhost:3000`.

---

## Default Sample Accounts (Seeded)

The database seed provides 17 test accounts (all passwords are set to `password123`):

| Username | Email | Role | Date of Birth |
|---|---|---|---|
| `AdaAdmin` | `ada.admin@example.com` | `admin` | `1990-01-15` |
| `AlanAdmin` | `alan.admin@example.com` | `admin` | `1988-06-23` |
| `grace_h` | `grace.hopper@example.com` | `member` | `1992-12-09` |
| `LinusT` | `linus@example.com` | `member` | `1989-12-28` |
| `matz` | `matz@example.com` | `member` | *(none / null)* |

---

## API Endpoints

### 1. Public JWKS
Returns the active public JSON Web Key Set used by verifiers and API Gateways.

```sh
curl http://localhost:3000/.well-known/jwks.json
```

**Response (200 OK):**
```json
{
  "keys": [
    {
      "kty": "RSA",
      "n": "...",
      "e": "AQAB",
      "kid": "c79e3ea83ad2d9ed32c3b68a4ce81eba0d6c492ecaee0baf17702fdeeb45cbaa"
    }
  ]
}
```

### 2. Login (Create Session)
Authenticates a user via **username** or **email** and password. Employs constant-time dummy BCrypt hashing to prevent user enumeration timing attacks.

```sh
# Login by username
curl -X POST http://localhost:3000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"login": "AdaAdmin", "password": "password123"}'

# Or login by email
curl -X POST http://localhost:3000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"login": "ada.admin@example.com", "password": "password123"}'
```

**Response (201 Created):**
```json
{
  "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": 1,
    "username": "AdaAdmin",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "role": "admin",
    "created_at": "...",
    "updated_at": "...",
    "email": "ada.admin@example.com",
    "date_of_birth": "1990-01-15"
  }
}
```

---

## Running Tests & Linters

- Run the full test suite (43 Minitest runs):
  ```sh
  bin/rails test
  ```
- Run the code style checker:
  ```sh
  bin/rubocop
  ```
