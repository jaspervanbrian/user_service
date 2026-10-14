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

### 3. List Users (Keyset Cursor Pagination & Custom Page Jumping)
```sh
# Fetch initial page (default 20, max 100)
curl -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/users?limit=10

# Fetch next page using opaque Base64 cursor (0 COUNT(*) queries, O(1) indexed lookup)
curl -H "Authorization: Bearer <TOKEN>" "http://localhost:3000/api/v1/users?limit=10&cursor=eyJpZCI6MTB9"

# Jump directly to custom page number
curl -H "Authorization: Bearer <TOKEN>" "http://localhost:3000/api/v1/users?limit=10&page=3"
```

**Response (200 OK):**
```json
{
  "users": [
    {
      "id": 1,
      "username": "AdaAdmin",
      "first_name": "Ada",
      "last_name": "Admin",
      "role": "admin",
      "email": "ada@example.com",
      "date_of_birth": "1990-01-15",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTB9",
    "has_next_page": true,
    "limit": 10,
    "page": 1
  }
}
```
*Note:* If viewed by a standard member, other users' `email` and `date_of_birth` fields are omitted completely from the payload.

### 4. Get User Profile
```sh
curl -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/users/1
```

### 5. Create User (Admin Only)
```sh
curl -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Grace",
      "last_name": "Hopper",
      "username": "ghopper",
      "email": "grace@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "role": "member"
    }
  }'
```

### 6. Update User (Self or Admin)
```sh
curl -X PATCH http://localhost:3000/api/v1/users/2 \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Michael",
      "last_name": "Updated"
    }
  }'
```
*Note:* Only administrators are permitted to update `:role`. Role updates from non-admins are filtered out by Pundit.

---

## High-Performance Bulk Seeding (50k - 100k Records)

The app includes an optimized bulk generator in `db/seeds.rb` that seeds 50,000+ users in ~1.9s using a single precomputed BCrypt digest and chunked `User.insert_all`:

```sh
# Standard fast seed (17 core users)
bin/rails db:seed

# Bulk dataset generator (50,000 users)
BULK_SEED=true bin/rails db:seed

# Custom count (e.g. 10,000 users)
BULK_SEED=true BULK_USERS_COUNT=10000 bin/rails db:seed
```

---

## React SPA Frontend (`client/`)

The application includes a responsive React SPA built with Vite, TypeScript, and React Router in [`client/`](client/).

### Features:
- **Authentication Guarding:** Visiting `/` redirects unauthenticated visitors to `/login`. Visiting `/login` while logged in redirects to `/`. Auto-logout on 401.
- **Quick Demo Logins:** 1-click login buttons for Admin (`ada@example.com` / `password123`) and Member (`MikeM` / `password123`).
- **ABAC/RBAC Visuals:** Clear policy banners. Private fields (`email`, `date_of_birth`) show a `🔒 Restricted` pill on unauthorized records.
- **Custom Pagination Footer:** Supports previous / next keyset cursor navigation, per-page limit selection, and a direct page number jump box (`Page [ 3 ] Jump`).
- **Edit & Create Modals:** Field-level validation error display matching Rails' 422 JSON errors.

### Running the Frontend:
```sh
cd client
bun install   # or npm install
bun run dev   # or npm run dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser.

### Client Linting & Production Build:
```sh
cd client
bun run lint   # Fast Oxlint validation (0 warnings)
bun run build  # Typecheck and Vite bundle
```

---

## Running Backend Tests & Linters

- Run the full test suite (76 Minitest runs):
  ```sh
  bin/rails test
  ```
- Run the code style checker:
  ```sh
  bin/rubocop
  ```
