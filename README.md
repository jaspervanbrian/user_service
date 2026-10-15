# User Service

[![Ruby](https://img.shields.io/badge/Ruby-4.0.6-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-CC0000.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-336791.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-8.10-DC382D.svg)](https://redis.io/)
[![React](https://img.shields.io/badge/React-19-61DAFB.svg)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6.svg)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-8.3-646CFF.svg)](https://vitejs.dev/)

A production-grade **Rails 8 API + React SPA** user management system built with asymmetric **RS256 JWT** authentication, attribute-based and role-based access control (**Pundit ABAC/RBAC**), zero-offset **keyset cursor pagination** with Redis ID caching, real-time username search, public registration, and modern Docker Compose deployment with **PostgreSQL 17** and **Redis 8**.

---

## Table of Contents
- [Docker Compose Quickstart (PostgreSQL 17 + Redis 8)](#docker-compose-quickstart-postgresql-17--redis-8)
- [Local Development (Zero-Docker / SQLite Option)](#local-development-zero-docker--sqlite-option)
- [Default Sample Accounts (Seeded)](#default-sample-accounts-seeded)
- [API Reference](#api-reference)
  - [1. Public RFC 7638 JWKS](#1-public-rfc-7638-jwks)
  - [2. User Sign Up (Public Registration)](#2-user-sign-up-public-registration)
  - [3. Login (Create Session)](#3-login-create-session)
  - [4. List Users (Keyset Cursor & Live Search)](#4-list-users-keyset-cursor--live-search)
  - [5. Get User Profile](#5-get-user-profile)
  - [6. Create User (Admin Only)](#6-create-user-admin-only)
  - [7. Update User (Self or Admin)](#7-update-user-self-or-admin)
- [Authorization & Security Verification (cURL Testing)](#authorization--security-verification-curl-testing)
- [High-Performance Bulk Seeding (50k - 100k Records)](#high-performance-bulk-seeding-50k---100k-records)
- [Environment Variables](#environment-variables)
- [Testing & Quality Assurance](#testing--quality-assurance)
- [Extending Beyond & System Architecture](#extending-beyond--system-architecture)
  - [System Architecture Diagram](#system-architecture-diagram)
  - [Architectural Highlights & Design Decisions](#architectural-highlights--design-decisions)
  - [Production Scaling & Future Extensions](#production-scaling--future-extensions)

---

## Docker Compose Quickstart (PostgreSQL 17 + Redis 8)

The fastest way to boot the full production-like environment with **PostgreSQL 17**, **Redis 8**, the **Rails 8 API**, and the **React SPA**:

```sh
# 1. Setup environment & build containers (validates Docker upfront)
bin/setup_docker

# 2. Start the application
docker compose up
```

### Services Started:
| Service | Image | Internal Port | Host Port | Description |
|---|---|---|---|---|
| **`client`** | `nginx:1.27-alpine` (multi-stage Bun build) | 80 | **`5173`** | React 19 SPA Frontend |
| **`api`** | `ruby:4.0.6-slim` | 3000 | **`3000`** | Rails 8 API Engine |
| **`db`** | `postgres:17-alpine` | 5432 | **`5432`** | PostgreSQL 17 Database |
| **`redis`** | `redis:8-alpine` | 6379 | **`6379`** | Redis 8 Cache Store |

Once booted:
- **Frontend SPA:** Open [http://localhost:5173](http://localhost:5173) in your browser.
- **Backend API:** Accessible at [http://localhost:3000](http://localhost:3000).
- **Auto-migration & Seeding:** The container automatically runs `rails db:prepare` and `rails db:seed` upon initial boot.

---

## Local Development (Zero-Docker / SQLite Option)

You can also run the application locally without Docker using `mise`. The app automatically defaults to SQLite and in-memory caching if PostgreSQL and Redis are not running.

### Prerequisites
- **mise:** [mise-en-place](https://mise.jdx.dev) for toolchain management (`curl https://mise.run | sh`)

### One-Command Setup
```sh
bin/setup
```
This script validates `mise`, syncs toolchains (`ruby 4.0.6` & `bun`), configures `.env` with a 2048-bit RS256 key, installs gems and frontend packages, runs migrations and seeds, and starts the development server.

### Start Frontend SPA
In a separate terminal:
```sh
cd client
bun dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser.

---

## Default Sample Accounts (Seeded)

The database seed provides pre-configured demo accounts (all passwords are set to `password123`):

| Username | Email | Role | Date of Birth | Description |
|---|---|---|---|---|
| `AdaAdmin` | `ada.admin@example.com` | `admin` | `1990-01-15` | Full administrative privileges |
| `AlanAdmin` | `alan.admin@example.com` | `admin` | `1988-06-23` | Secondary administrator |
| `grace_h` | `grace.hopper@example.com` | `member` | `1992-12-09` | Standard member |
| `LinusT` | `linus@example.com` | `member` | `1989-12-28` | Standard member |
| `matz` | `matz@example.com` | `member` | *(none / null)* | Member with optional DOB omitted |

---

## API Reference

### 1. Public RFC 7638 JWKS
Returns the active public JSON Web Key Set used by token verifiers and API Gateways.

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

---

### 2. User Sign Up (Public Registration)
Creates a new member account and automatically issues an asymmetric RS256 JWT session. Strictly enforces `member` role even if client passes elevated roles.

```sh
curl -X POST http://localhost:3000/api/v1/registrations \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Katherine",
      "last_name": "Johnson",
      "username": "kjohnson",
      "email": "kjohnson@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "date_of_birth": "1918-08-26"
    }
  }'
```

**Response (201 Created):**
```json
{
  "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": 18,
    "username": "kjohnson",
    "first_name": "Katherine",
    "last_name": "Johnson",
    "role": "member",
    "email": "kjohnson@example.com",
    "date_of_birth": "1918-08-26",
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

### 3. Login (Create Session)
Authenticates a user via either **username** or **email** and password. Employs constant-time dummy BCrypt hashing to prevent user enumeration timing attacks.

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
    "last_name": "Admin",
    "role": "admin",
    "email": "ada.admin@example.com",
    "date_of_birth": "1990-01-15",
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

### 4. List Users (Keyset Cursor & Live Search)
Returns a page of users filtered by authorization policy. Supports limit bounds and real-time username search query.

```sh
# Initial page (default limit 20, max 100)
curl -H "Authorization: Bearer <TOKEN>" "http://localhost:3000/api/v1/users?limit=10"

# Next page using opaque Base64 cursor (O(1) indexed seek, 0 COUNT queries)
curl -H "Authorization: Bearer <TOKEN>" "http://localhost:3000/api/v1/users?limit=10&cursor=eyJpZCI6MTB9"

# Filter by username search query
curl -H "Authorization: Bearer <TOKEN>" "http://localhost:3000/api/v1/users?query=ada"
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
      "email": "ada.admin@example.com",
      "date_of_birth": "1990-01-15",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTB9",
    "has_next_page": true,
    "limit": 10
  }
}
```
*Note:* Unauthorized viewers have `email` and `date_of_birth` completely omitted from other users' records.

---

### 5. Get User Profile
Fetches a single user record by ID.

```sh
curl -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/users/1
```

---

### 6. Create User (Admin Only)
Administrators can create users with any role.

```sh
curl -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Margaret",
      "last_name": "Hamilton",
      "username": "mhamilton",
      "email": "margaret@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "role": "admin"
    }
  }'
```

---

### 7. Update User (Self or Admin)
Users can update their own details. Only administrators can change `:role`.

```sh
curl -X PATCH http://localhost:3000/api/v1/users/2 \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Grace",
      "last_name": "Brewster Hopper"
    }
  }'
```

---

## Authorization & Security Verification (cURL Testing)

This guide provides real-world `curl` commands to test authentication, role-based authorization (RBAC), and attribute-based field masking (ABAC).

### Setup: Obtain Tokens for Admin and Member

```sh
# 1. Obtain an Admin Token (AdaAdmin):
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"login": "AdaAdmin", "password": "password123"}' | jq -r .token)

# 2. Obtain a Member Token (Grace Hopper):
MEMBER_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"login": "grace.hopper@example.com", "password": "password123"}' | jq -r .token)
```

---

### Scenario 1: Unauthenticated Request (Failure — 401 Unauthorized)
Requesting a protected endpoint without an `Authorization` header returns HTTP 401 and includes the `WWW-Authenticate: Bearer` challenge header.

```sh
curl -i http://localhost:3000/api/v1/users
```

**HTTP Response:**
```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer error="invalid_token"
Content-Type: application/json

{"error":"Missing authentication token"}
```

---

### Scenario 2: Tampered or Invalid Token (Failure — 401 Unauthorized)
Requesting with an altered or improperly signed JWT returns HTTP 401.

```sh
curl -i -H "Authorization: Bearer invalid.token.payload" http://localhost:3000/api/v1/users
```

**HTTP Response:**
```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer error="invalid_token"
Content-Type: application/json

{"error":"Invalid token: Signature verification failed"}
```

---

### Scenario 3: RBAC Privilege Enforcement (Failure — 403 Forbidden)
A standard `member` attempts an admin-only action, such as creating a new user:

```sh
curl -i -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $MEMBER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Unauthorized",
      "last_name": "Create",
      "username": "unauthorized",
      "email": "hacker@example.com",
      "password": "password123"
    }
  }'
```

**HTTP Response:**
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{"error":"You are not authorized to perform this action"}
```

---

### Scenario 4: RBAC Success — Admin Action (Success — 201 Created)
An `admin` executes the same action with elevated privileges:

```sh
curl -i -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "first_name": "Margaret",
      "last_name": "Hamilton",
      "username": "mhamilton",
      "email": "margaret@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "role": "admin"
    }
  }'
```

**HTTP Response:**
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "user": {
    "id": 18,
    "username": "mhamilton",
    "first_name": "Margaret",
    "last_name": "Hamilton",
    "role": "admin",
    "email": "margaret@example.com",
    "date_of_birth": null,
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

### Scenario 5: ABAC Attribute Masking Verification (Success — 200 OK)
Notice the difference in private field visibility (`email` and `date_of_birth`) between an Admin viewer and a Member viewer:

```sh
# View another user as Admin (private fields visible):
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:3000/api/v1/users/3 | jq .user
```
**Admin Output (sees private fields):**
```json
{
  "id": 3,
  "username": "grace_h",
  "first_name": "Grace",
  "last_name": "Hopper",
  "role": "member",
  "email": "grace.hopper@example.com",
  "date_of_birth": "1992-12-09"
}
```

```sh
# View another user as Member (private fields stripped):
curl -s -H "Authorization: Bearer $MEMBER_TOKEN" http://localhost:3000/api/v1/users/1 | jq .user
```
**Member Output (keys completely omitted, not null):**
```json
{
  "id": 1,
  "username": "AdaAdmin",
  "first_name": "Ada",
  "last_name": "Admin",
  "role": "admin"
}
```

---

### Scenario 6: Privilege Escalation Prevention (Safe Parameter Filtering)
A member attempts to elevate their own role to `admin` via profile update:

```sh
curl -s -X PATCH http://localhost:3000/api/v1/users/3 \
  -H "Authorization: Bearer $MEMBER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user": {"role": "admin", "first_name": "Grace"}}' | jq .user
```

**Output:**
```json
{
  "id": 3,
  "username": "grace_h",
  "first_name": "Grace",
  "role": "member"
}
```
*(Role escalation is filtered out by Pundit `permitted_attributes`; the user remains a `member` while safe fields like `first_name` are updated).*

---

## High-Performance Bulk Seeding (50k - 100k Records)

The app includes an optimized bulk dataset generator in `db/seeds.rb` that generates 50,000+ users in ~1.9s using a single precomputed BCrypt digest and chunked `User.insert_all`:

### Running Seeds in Docker:
```sh
# Standard seed (17 core users):
docker compose exec api bin/rails db:seed

# Bulk dataset generator (50,000 users in ~1.9s):
docker compose exec -e BULK_SEED=true api bin/rails db:seed

# Custom count (e.g. 100,000 users):
docker compose exec -e BULK_SEED=true -e BULK_USERS_COUNT=100000 api bin/rails db:seed
```

### Running Seeds Locally (without Docker):
```sh
# Standard seed (17 core users):
bin/rails db:seed

# Bulk dataset generator (50,000 users):
BULK_SEED=true bin/rails db:seed

# Custom count (e.g. 100,000 users):
BULK_SEED=true BULK_USERS_COUNT=100000 bin/rails db:seed
```

---

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | *(None / SQLite fallback)* | Connection URL for PostgreSQL 17 (e.g. `postgres://user:pass@host:5432/dbname`) |
| `REDIS_URL` | *(None / Memory store fallback)* | Connection URL for Redis 8 cache store (e.g. `redis://redis:6379/0`) |
| `JWT_PRIVATE_KEY` | Rails credentials | RSA 2048-bit PEM private key used to sign session tokens |
| `JWT_ISSUER` | `http://localhost:3000` | Issuer claim (`iss`) embedded in tokens and matched on verify |
| `JWT_TTL_SECONDS` | `900` (15 mins) | Token lifetime duration in seconds |
| `AUTH_VERIFIER` | `local` | `local` (in-process RSA verification) or `gateway` (edge identity trust) |
| `VITE_API_URL` | `http://localhost:3000/api/v1` | API base endpoint consumed by the React SPA frontend |

---

## Testing & Quality Assurance

### Run Rails Backend Tests
Full automated Minitest suite covering authentication, RBAC authorization, Pundit scopes, registrations, sessions, and keyset pagination:
```sh
bin/rails test
```

### Run Ruby Linter (Omakase)
```sh
bin/rubocop
```

### Run Frontend Linter & Build
```sh
cd client
bun run lint   # Oxlint (0 warnings, 0 errors)
bun run build  # TypeScript typecheck & Vite production bundle
```

---

## Extending Beyond & System Architecture

### System Architecture Diagram

```mermaid
graph TD
    Client["React 19 SPA (Vite + TypeScript)<br/>:5173"]
    API["Rails 8 API Server (Puma)<br/>:3000"]
    PG[("PostgreSQL 17<br/>Primary Store")]
    Redis[("Redis 8<br/>Keyset ID & Data Cache")]
    Gateway["API Gateway / External Verifier<br/>(RFC 7638 JWKS)"]

    Client -->|"RS256 Bearer JWT + REST JSON"| API
    API -->|"CRUD Queries & Expression Index"| PG
    API -->|"Keyset Candidate IDs & Caching"| Redis
    Gateway -->|"GET /.well-known/jwks.json"| API
```

---

### Architectural Highlights & Design Decisions

#### 1. Asymmetric RS256 JWT Authentication & Edge Verification
- **Private Key Signing:** Tokens are signed using an RSA 2048-bit private key.
- **RFC 7638 Deterministic `kid`:** The Key ID header (`kid`) is computed directly from the SHA-256 JWK thumbprint of the public key (`JWT::JWK.new(key).kid`), ensuring zero-config alignment between issued token headers and JWKS.
- **Zero-PII Token Payload:** The JWT claims only carry standard claims (`sub`, `iss`, `aud`, `exp`, `nbf`, `iat`, `jti`) and authorization context (`role`). No sensitive PII (`email`, `date_of_birth`) ever lives in the token.
- **Public JWKS Endpoint:** `GET /.well-known/jwks.json` serves the public key set so downstream microservices and edge API Gateways can independently verify tokens without database hits.
- **Swappable Verifier Seam (`Auth.verifier`):**
  - **Local Verifier (`Auth::Verifiers::Local`):** In-process cryptographically verifies token signatures against `Auth.key_set.to_jwks`.
  - **Gateway Verifier (`Auth::Verifiers::Gateway`):** Configurable via `AUTH_VERIFIER=gateway` to trust upstream identity headers (`X-User-Id`, `X-User-Role`) injected by an API Gateway (AWS HTTP API, Kong, Envoy) that verified the JWT at the perimeter.

#### 2. Attribute-Based & Role-Based Access Control (ABAC + RBAC)
- **Role Hierarchy:** Two roles: `member` and `admin`.
- **Attribute-Based Masking:** `email` and `date_of_birth` are classified as sensitive PII.
- **Field Omission vs Null:** When a member views other users, private field keys are completely stripped from the JSON response by `UserSerializer` rather than set to `null`, ensuring clients can clearly differentiate between an unprovided field and an unauthorized field.
- **Role Escalation Protection:** Only administrators can promote or demote user roles. Public sign-up strictly creates `member` accounts.

#### 3. Pure Keyset Cursor Pagination & Scalability
- **Zero `OFFSET` Penalty:** Conventional `OFFSET N` scans and discards $N$ records ($O(N)$ penalty). Our service implements pure keyset cursor pagination (`WHERE id > cursor_id`), operating in **strictly $O(1)$ constant time** regardless of depth.
- **Zero `COUNT(*)` Queries:** The service plucks `limit + 1` primary key IDs. If result count exceeds `limit`, `has_next_page` is true and the last record ID is Base64 URL-safe encoded into an opaque cursor token.
- **Redis ID Caching:** The array of candidate IDs for each cursor and query is cached in Redis (`users:cursor_ids:cursor=...`) for 5 minutes, eliminating redundant database scans on repeated navigation.
- **Live Search Query Integration:** Searching by username (`WHERE lower(username) LIKE ? AND id > ?`) preserves pure keyset cursor pagination.

#### 4. Database Expression Indexing & Timing Attack Mitigation
- **Case-Insensitive Uniqueness:** PostgreSQL functional B-Tree index on `lower(username)` enforces uniqueness at the database engine level while preserving casing for display (`AdaAdmin`).
- **Constant-Time BCrypt Verification:** When an unauthenticated visitor logs in with a non-existent email or username, the system performs a dummy BCrypt hash verification (`BCrypt::Password.create('', cost: ...)`), equalizing response times and eliminating username enumeration timing attacks.

---

### Production Scaling & Future Extensions

When scaling this service to millions of users and high concurrent throughput, the existing architecture is primed for the following extensions:

#### 1. PostgreSQL Read Replicas (Rails Multi-DB)
Rails 8 natively supports primary/replica read-write splitting. By adding a replica configuration to `config/database.yml`:
```yaml
production:
  primary:
    adapter: postgresql
    url: <%= ENV['DATABASE_URL'] %>
  primary_replica:
    adapter: postgresql
    url: <%= ENV['DATABASE_REPLICA_URL'] %>
    replica: true
```
All read-only cursor queries (`UsersController#index`, `UsersController#show`) automatically route to the replica pool, reserving primary database CPU for user sign-ups and profile updates.

#### 2. Distributed Rate Limiting (Redis Sliding Window)
To protect `/api/v1/sessions` and `/api/v1/registrations` against brute-force credential stuffing and registration spam, plug `rack-attack` directly into the existing Redis 8 cluster with sliding-window throttling:
```ruby
Rack::Attack.throttle('logins/ip', limit: 5, period: 60.seconds) do |req|
  req.ip if req.path == '/api/v1/sessions' && req.post?
end
```

#### 3. Asynchronous Outbox / Event Bus
When users register or update profiles, emit domain events (`user.created`, `user.updated`) over Redis Streams, Kafka, or AWS SNS/SQS using Solid Queue or transactional outbox tables. Downstream services (notification services, billing, audit logs) react asynchronously without coupling to the user database.

#### 4. Zero-Downtime Key Rotation Runbook
The `Auth::KeySet` architecture supports simultaneous active keys. During rotation:
1. Generate a new RSA private key (Key B).
2. Add Key B's public key to the JWKS endpoint while Key A continues signing.
3. Switch signing to Key B. Existing tokens signed with Key A remain valid until natural expiry (`expires_in: 900`).
4. Retire Key A once all in-flight tokens expire.
