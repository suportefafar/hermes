# 📬 Email Gateway Service — Full Specification

## Overview

A centralized, internal email dispatch service built with **Ruby on Rails**. All other services (Rails, WordPress, Node.js, Python) delegate email sending to this service via a simple authenticated HTTP API. The service manages queuing, rate limiting, retries, SMTP fallback, and provides a dashboard for monitoring and operations.

---

## 1. Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Services                          │
│  (Rails apps, WordPress, Node.js, Python)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ POST /api/v1/messages
                       │ Authorization: Bearer <token>
                       ▼
┌─────────────────────────────────────────────────────────────┐
│               Email Gateway (Rails API + Dashboard)         │
│                                                             │
│  ┌────────────┐   ┌─────────────┐   ┌──────────────────┐   │
│  │ Ingestion  │   │  Scheduler  │   │ Delivery Worker  │   │
│  │ Controller │   │  (BG Job)   │   │   (BG Job)       │   │
│  └─────┬──────┘   └──────┬──────┘   └────────┬─────────┘   │
│        │                 │                   │              │
│        ▼                 ▼                   ▼              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   PostgreSQL DB                      │   │
│  │  (email_messages, delivery_attempts, api_clients,   │   │
│  │   smtp_providers, solid_queue_*)                    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
          External SMTP Provider (Primary / Fallback)
```

### Technology Stack

| Concern              | Choice                          |
|----------------------|---------------------------------|
| Framework            | Ruby on Rails (API + Views)     |
| Background Jobs      | Solid Queue (DB-backed, no Redis)|
| Dashboard UI         | Hotwire (Turbo + Stimulus)      |
| Database             | PostgreSQL                      |
| Auth (Dashboard)     | Devise (session-based)          |
| Auth (API)           | Bearer token (custom middleware) |
| SMTP                 | ActionMailer + configurable SMTP|
| Containerization     | Docker + Docker Compose         |

---

## 2. Data Models

### `email_messages`

| Column           | Type      | Notes                                              |
|------------------|-----------|----------------------------------------------------|
| `id`             | uuid      | Primary key                                        |
| `api_client_id`  | fk        | Which token/client submitted this                  |
| `from`           | string    | Sender address (overridable per-request)           |
| `reply_to`       | string    | Optional                                           |
| `to`             | string[]  | Array of recipient addresses                       |
| `cc`             | string[]  | Optional                                           |
| `bcc`            | string[]  | Optional                                           |
| `subject`        | string    |                                                    |
| `body_html`      | text      | HTML content                                       |
| `attachments`    | jsonb     | Array of `{filename, content_type, content_base64}`|
| `status`         | enum      | `pending`, `sent`, `failed`, `malformed`           |
| `attempts`       | integer   | Default 0                                          |
| `next_attempt_at`| datetime  | When scheduler should next pick this up            |
| `smtp_provider_id`| fk       | Which provider ultimately sent it (if sent)        |
| `error_message`  | text      | Last error detail                                  |
| `is_manual_resend`| boolean  | True if triggered from dashboard (skips rate limit)|
| `created_at`     | datetime  |                                                    |
| `updated_at`     | datetime  |                                                    |

### `delivery_attempts`

Append-only audit trail for every send attempt.

| Column             | Type     | Notes                        |
|--------------------|----------|------------------------------|
| `id`               | uuid     |                              |
| `email_message_id` | fk       |                              |
| `smtp_provider_id` | fk       |                              |
| `attempt_number`   | integer  |                              |
| `smtp_response_code`| integer |                              |
| `smtp_response_msg`| text     |                              |
| `outcome`          | enum     | `delivered`, `soft_bounce`, `hard_bounce`, `timeout`, `rate_limited` |
| `attempted_at`     | datetime |                              |

### `api_clients`

| Column       | Type    | Notes                              |
|--------------|---------|------------------------------------|
| `id`         | uuid    |                                    |
| `name`       | string  | e.g. "WordPress Site", "Node App"  |
| `token`      | string  | Hashed bearer token (unique)       |
| `active`     | boolean | Revoke by setting to false         |
| `created_at` | datetime|                                    |

### `smtp_providers`

| Column         | Type    | Notes                                |
|----------------|---------|--------------------------------------|
| `id`           | uuid    |                                      |
| `name`         | string  | e.g. "SendGrid Primary"              |
| `host`         | string  |                                      |
| `port`         | integer |                                      |
| `username`     | string  |                                      |
| `password`     | string  | Encrypted at rest                    |
| `from_address` | string  | Default from address for this provider|
| `priority`     | integer | 1 = primary, 2+ = fallback           |
| `active`       | boolean |                                      |
| `failure_count`| integer | Rolling failures in current window   |
| `last_used_at` | datetime|                                      |

### `system_settings`

Key-value store for runtime-configurable settings.

| Key                        | Default | Description                            |
|----------------------------|---------|----------------------------------------|
| `rate_limit_per_minute`    | `2`     | Global emails per minute               |
| `fallback_threshold_pct`   | `50`    | % failures before switching provider   |
| `max_retry_attempts`       | `4`     |                                        |

---

## 3. API Contract

### Authentication

All API requests must include:
```
Authorization: Bearer <client_token>
```
- Tokens are validated against `api_clients.token` (hashed).
- Revoked (`active: false`) tokens return `401 Unauthorized`.
- Requests outside the Docker network without HTTPS return `403 Forbidden`.

---

### `POST /api/v1/messages`

Submit an email for delivery.

**Request Body (JSON):**
```json
{
  "from": "sender@example.com",
  "reply_to": "support@example.com",
  "to": ["user@example.com", "other@example.com"],
  "cc": ["cc@example.com"],
  "bcc": ["bcc@example.com"],
  "subject": "Welcome!",
  "body_html": "<h1>Hello!</h1>",
  "attachments": [
    {
      "filename": "report.pdf",
      "content_type": "application/pdf",
      "content": "<base64-encoded-string>"
    }
  ]
}
```

- `to` is **required** (at least one address).
- `subject` and `body_html` are **required**.
- `from` is optional; defaults to the SMTP provider's configured `from_address`.
- All email addresses are validated with format check.

**Responses:**

| Code | Meaning                                                   |
|------|-----------------------------------------------------------|
| `202`| Accepted — job queued. Returns `{"id": "<message_uuid>"}` |
| `400`| Validation error — also saved to DB as `status: malformed`, no retries |
| `401`| Missing or invalid token                                  |
| `403`| HTTPS required (non-internal request over HTTP)           |
| `422`| Unprocessable entity (malformed JSON)                     |

> **Note:** On `400`, the message is persisted to `email_messages` with `status: malformed` so it appears in the dashboard for visibility, but `next_attempt_at` is null and `attempts` is locked.

---

## 4. Processing Pipeline

### Stage 1 — Ingestion (API Controller)
1. Authenticate token → `401` if invalid/revoked.
2. Parse and validate request body.
3. If **invalid**: persist with `status: malformed`, return `400`.
4. If **valid**: persist with `status: pending`, `next_attempt_at: now`, return `202`.

### Stage 2 — Scheduler (Recurring Background Job)
- Runs continuously (via Solid Queue recurring job).
- Queries: `email_messages WHERE status = 'pending' AND next_attempt_at <= NOW()`.
- For each message:
  - **Check global rate limiter** (2/min sliding window, stored in DB or memory):
    - **Throttled?** → Update `next_attempt_at = now + 5s`. No retry consumed. Skip.
    - **Allowed?** → Decrement rate limit counter. Enqueue `DeliveryWorker` job.

### Stage 3 — Delivery Worker (Background Job)
1. Select active primary SMTP provider (lowest `priority` where `active: true`).
2. Check **fallback threshold**: if `failure_count` on primary > 50% of recent batch → switch to next provider.
3. Attempt send via ActionMailer with selected provider.
4. Record a `delivery_attempts` row with outcome.
5. Handle response:

| SMTP Response     | Action                                                        |
|-------------------|---------------------------------------------------------------|
| `2xx` (success)   | `status: sent`. Done.                                         |
| `5xx` (hard bounce)| `status: failed`. No retry. Record error.                    |
| `4xx` / timeout   | Soft bounce. Increment `attempts`. Schedule retry (see §5).   |

### Stage 4 — Retry Logic

Max **4 attempts**. Retry schedule (from time of failure):

| Attempt | Delay   |
|---------|---------|
| 1st     | 1 min   |
| 2nd     | 30 min  |
| 3rd     | 8 hours |
| 4th     | 24 hours|

After 4th failure → `status: failed`. Message enters the dead letter view in the dashboard.

### Manual Resend (from Dashboard)
- Sets `status: pending`, `next_attempt_at: now`, resets `attempts: 0`.
- Sets `is_manual_resend: true` → Scheduler **bypasses** rate limiter for this message.
- Full delivery pipeline runs normally.

---

## 5. SMTP Provider Fallback

- Providers are ranked by `priority` (1 = primary).
- **Automatic switch**: If `failure_count` on current provider exceeds 50% of the last batch window, the Scheduler switches to the next `active` provider for subsequent sends.
- **Per-send fallback**: If the primary fails on a single attempt (soft bounce), the retry on the next attempt will re-evaluate provider health and may use the fallback.
- Provider health resets at the start of each rate-limit window.

---

## 6. Dashboard

### Authentication
- Session-based login (Devise).
- Single admin user seeded on first boot (`db/seeds.rb`).
- Login credentials configurable via ENV (`ADMIN_EMAIL`, `ADMIN_PASSWORD`).

### Pages & Features

#### `/dashboard` — Overview
- Total emails: Pending / Sent / Failed counts (today and all-time).
- Warning banner if: primary provider failure rate > 50% AND no fallback available.
- Recent emails list (last 20).

#### `/dashboard/messages` — Email Log
- Paginated list of all `email_messages`.
- **Columns**: Timestamp, Client App, To, Subject, Status, Attempts.
- **Search/filter**: by recipient, subject, client app name.
- **Status filter**: All / Pending / Sent / Failed / Malformed.
- Click row → message detail view.

#### `/dashboard/messages/:id` — Message Detail
- Full header info (from, to, cc, bcc, reply-to, subject, client, timestamps).
- **HTML body preview** (rendered in sandboxed iframe).
- **Delivery attempts log** (table: attempt #, provider used, SMTP code, outcome, timestamp).
- **"Resend" button** (for Failed / Malformed messages) — triggers manual resend.

#### `/dashboard/clients` — API Client Tokens
- List all clients (name, token prefix, active status, created_at).
- **Create** new client → generate token, show once.
- **Revoke** client → sets `active: false`.
- **Reactivate** revoked client.

#### `/dashboard/providers` — SMTP Providers
- List providers with priority, status, failure count.
- **Create / Edit / Delete** providers.
- Set which is primary (priority 1) and which are fallbacks.

#### `/dashboard/settings` — System Settings
- Edit `rate_limit_per_minute`.
- Edit `fallback_threshold_pct`.
- Edit `max_retry_attempts`.

---

## 7. Infrastructure & Deployment

### Docker Compose Service

```yaml
# Inside your existing compose.yaml
email-gateway:
  build: ./email-gateway
  environment:
    - DATABASE_URL=...
    - ADMIN_EMAIL=admin@internal.com
    - ADMIN_PASSWORD=...
    - RAILS_ENV=production
    - SECRET_KEY_BASE=...
  depends_on:
    - db
  networks:
    - internal
```

### Reverse Proxy

- Dashboard (`/`) → accessible externally via HTTPS through reverse proxy.
- API (`/api/v1/`) → accessible both:
  - Externally (HTTPS only, with token).
  - Internally within Docker network (HTTP allowed, with token).

### HTTPS Enforcement

A `before_action` in `ApplicationController` (or Rack middleware) checks:
- If request comes from outside the Docker network (non-RFC1918 IP) and is not HTTPS → return `403`.
- Internal Docker network requests (10.x.x.x, 172.x.x.x) always pass through regardless of scheme.

---

## 8. Project Structure (Rails)

```
email-gateway/
├── app/
│   ├── controllers/
│   │   ├── api/v1/messages_controller.rb   # Ingestion endpoint
│   │   └── dashboard/
│   │       ├── messages_controller.rb
│   │       ├── clients_controller.rb
│   │       ├── providers_controller.rb
│   │       └── settings_controller.rb
│   ├── jobs/
│   │   ├── scheduler_job.rb                # Recurring — polls queue
│   │   └── delivery_job.rb                 # Per-message delivery
│   ├── models/
│   │   ├── email_message.rb
│   │   ├── delivery_attempt.rb
│   │   ├── api_client.rb
│   │   ├── smtp_provider.rb
│   │   └── system_setting.rb
│   ├── services/
│   │   ├── rate_limiter.rb
│   │   ├── smtp_selector.rb                # Provider selection + fallback logic
│   │   └── email_validator.rb
│   └── views/
│       └── dashboard/                      # Hotwire/Turbo views
├── db/
│   └── seeds.rb                            # Admin user seed
├── Dockerfile
└── docker-compose.yml
```

---

## 9. Open Questions / Future Considerations

- [ ] **Webhooks**: Should the gateway POST a callback to the originating service on delivery/failure? (Future feature)
- [ ] **Metrics endpoint**: A `/metrics` Prometheus-compatible endpoint for external monitoring tools.
- [ ] **Email templates**: Should the gateway manage reusable templates, or do clients always send full HTML?
- [ ] **Unsubscribe handling**: As the system grows, tracking bounces and unsubscribes at the gateway level becomes important.
- [ ] **Multi-admin**: Currently one seeded admin. Future: Devise-based admin management.
