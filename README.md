# ✉️ Hermes — Centralized Email Gateway

Hermes is the central email dispatch service for all internal applications (Rails, WordPress, Node.js, Python, etc.). It provides a unified HTTP API to offload email sending, handling all the heavy lifting such as:

- **Rate Limiting:** Global throttling (e.g., 100 emails/hour) to prevent SMTP blacklisting.
- **Queuing & Retries:** Automatic retries for soft bounces (4xx) with exponential backoff (1m, 30m, 8h, 24h).
- **SMTP Fallback:** Automatically switches to a fallback SMTP provider if the primary provider experiences high failure rates.
- **Monitoring:** A centralized dashboard to view email delivery status, errors, and an HTML preview of the actual sent emails.

---

## 🚀 How to Use the API

All services must communicate with Hermes via the REST API. 

### 1. Get an API Token
Before a service can send emails, an administrator must create an API Client in the [Hermes Dashboard](/dashboard/clients). 
Generate the token, and store it securely in your service's environment variables.

## Runtime configuration

Provision a private `.env` from `.env.production.example` and keep it out of Git with mode `600`. Configure your database connection, session secret, administrator credentials and three independent encryption keys before starting the app. Generate each encryption key separately with `ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'`. Development also requires private encryption keys; keep them stable so existing encrypted data remains readable.

Set `HERMES_DESIGN_SYSTEM_URL` to the base URL of your design system assets (the directory containing `farmacia-ds.min.css`, `farmacia-ds.min.js` and `fonts/`). It defaults to `/design-system`. Set `HERMES_DEVELOPMENT_HOST` when using a custom local hostname. Configure these deployment-specific values in private environment files.

After deployment, sign in at `/dashboard`, configure your SMTP provider, and create a separate API client for each application. Store each token privately; the dashboard displays it once.

Asset compilation uses temporary encryption keys only with `SECRET_KEY_BASE_DUMMY=1`; never set this variable in the runtime environment.

If an existing installation used the former public encryption defaults, stop and plan a data migration before changing keys. Preserve access to the old keys privately to decrypt and re-encrypt existing records, and rotate the SMTP credentials they protected. Removing Git history does not revoke credentials or remove third-party copies.

### 2. The Endpoint

```http
POST http://hermes:80/api/v1/messages
```
*(If calling from inside the Docker network, use `http://hermes:80`. If calling externally, use `https://mail.example.com`)*

### 3. Request Headers

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <your_api_token>` |
| `Content-Type` | `application/json` |

### 4. JSON Payload Format

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `to_addresses` | `Array` or `String` | **Yes** | One or more recipient email addresses. |
| `subject` | `String` | **Yes** | The subject of the email. |
| `body_html` | `String` | **Yes** | The full HTML body of the email. |
| `from_name` | `String` | No | Display name for the sender; keeps the provider address when `from_address` is omitted. Maximum 255 characters, without line breaks. |
| `from_address` | `String` | No | Overrides the default provider sender address. |
| `reply_to` | `String` | No | Sets a Reply-To header. |
| `cc_addresses` | `Array` or `String` | No | Carbon copy recipients. |
| `bcc_addresses` | `Array` or `String` | No | Blind carbon copy recipients. |
| `attachments` | `Array` | No | Array of objects: `{ "filename": "x.pdf", "content_type": "application/pdf", "content": "<base64>" }` |

### 5. Responses

- `202 Accepted`: Payload valid, email has been queued successfully.
- `400 Bad Request`: Missing required fields or invalid email formats (this failure is logged in the Hermes dashboard).
- `401 Unauthorized`: Invalid or revoked Bearer token.
- `403 Forbidden`: Request made externally without HTTPS.

---

## 💻 Code Examples

### cURL
```bash
curl -X POST http://hermes:80/api/v1/messages \
  -H "Authorization: Bearer ${HERMES_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "to_addresses": ["user@example.com"],
    "subject": "Welcome to our platform!",
    "body_html": "<h1>Hello!</h1><p>Thanks for joining.</p>"
  }'
```

### Ruby (Rails / Faraday)
```ruby
# In your Rails app, you don't need ActionMailer. Just a simple HTTP call.
Faraday.post("http://hermes:80/api/v1/messages") do |req|
  req.headers['Authorization'] = "Bearer #{ENV['HERMES_API_TOKEN']}"
  req.headers['Content-Type'] = 'application/json'
  req.body = {
    to_addresses: "user@example.com",
    subject: "Weekly Report",
    body_html: "<p>Here is your report...</p>"
  }.to_json
end
```

### PHP (WordPress)
```php
$payload = array(
    'to_addresses' => 'user@example.com',
    'subject'      => 'Password Reset',
    'body_html'    => '<p>Click here to reset...</p>'
);

$response = wp_remote_post( 'http://hermes:80/api/v1/messages', array(
    'headers'     => array(
        'Authorization' => 'Bearer ' . HERMES_API_TOKEN,
        'Content-Type'  => 'application/json; charset=utf-8'
    ),
    'body'        => wp_json_encode( $payload ),
    'data_format' => 'body',
) );
```

### Node.js (Fetch)
```javascript
await fetch("http://hermes:80/api/v1/messages", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${process.env.HERMES_API_TOKEN}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    to_addresses: ["user@example.com", "admin@example.com"],
    subject: "Node.js Alert",
    body_html: "<strong>Something happened!</strong>"
  })
});
```

### Python (Requests)
```python
import requests
import os

requests.post(
    "http://hermes:80/api/v1/messages",
    headers={"Authorization": f"Bearer {os.getenv('HERMES_API_TOKEN')}"},
    json={
        "to_addresses": ["user@example.com"],
        "subject": "Data Processing Complete",
        "body_html": "<p>Your files are ready.</p>"
    }
)
```

## Rotating encryption keys

Provision new independent current keys privately. For the transition, also configure `HERMES_ENCRYPTION_PREVIOUS_PRIMARY_KEY` and `HERMES_ENCRYPTION_PREVIOUS_KEY_DERIVATION_SALT` with the existing values. Deploy the version that supports previous keys, then run `bin/rails hermes:rotate_encryption`. The task locks provider records, re-encrypts their passwords in a transaction and verifies decryption using only the current keys. After successful verification, remove both previous variables and recreate the service through your deployment workflow. Keep database backups aligned with the keys needed to restore them. Previous keys support SMTP password decryption only.
