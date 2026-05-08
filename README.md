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

### 2. The Endpoint

```http
POST http://hermes:8009/api/v1/messages
```
*(If calling from inside the Docker network, use `http://hermes:8009`. If calling externally, use `https://hermes.farmacia.ufmg.br`)*

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
curl -X POST http://hermes:8009/api/v1/messages \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
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
Faraday.post("http://hermes:8009/api/v1/messages") do |req|
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

$response = wp_remote_post( 'http://hermes:8009/api/v1/messages', array(
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
await fetch("http://hermes:8009/api/v1/messages", {
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
    "http://hermes:8009/api/v1/messages",
    headers={"Authorization": f"Bearer {os.getenv('HERMES_API_TOKEN')}"},
    json={
        "to_addresses": ["user@example.com"],
        "subject": "Data Processing Complete",
        "body_html": "<p>Your files are ready.</p>"
    }
)
```
