# Apideck SDK Patterns (for detection)

Use these patterns to scan a project and detect Apideck usage. Each pattern maps to a specific migration action.

## Python

### New SDK (`apideck-unify`)

**Import patterns:**
```python
from apideck_unify import Apideck
from apideck_unify import models
```

**Client creation:**
```python
apideck = Apideck(
    api_key="...",
    consumer_id="...",
    app_id="...",
)
```

**API calls:**
```python
res = apideck.hris.employees.list(service_id="workday", limit=20)
res = apideck.crm.contacts.list(service_id="salesforce")
res = apideck.accounting.invoices.list(service_id="quickbooks")
```

**Pagination:**
```python
while res is not None:
    for item in res.data:
        process(item)
    res = res.next()
```

### Legacy SDK (`apideck`)

**Import patterns:**
```python
import apideck
from apideck.api import crm_api, hris_api
```

**Client creation:**
```python
configuration = apideck.Configuration()
configuration.api_key['apiKey'] = '...'
configuration.api_key_prefix['apiKey'] = 'Bearer'

with apideck.ApiClient(configuration) as api_client:
    api_instance = crm_api.CrmApi(api_client)
```

**API calls:**
```python
api_response = api_instance.contacts_all(
    consumer_id='...',
    app_id='...',
    service_id='...',
)
```

## Node / TypeScript

### New SDK (`@apideck/unify`)

**Import patterns:**
```typescript
import { Apideck } from "@apideck/unify";
```

**Client creation:**
```typescript
const apideck = new Apideck({
  apiKey: "...",
  consumerId: "...",
  appId: "...",
});
```

**API calls:**
```typescript
const res = await apideck.crm.contacts.list({ serviceId: "salesforce", limit: 20 });
const res = await apideck.hris.employees.list({ serviceId: "workday" });
```

### Legacy SDK (`@apideck/node`)

**Import patterns:**
```typescript
import { Apideck } from "@apideck/node";
```

**API calls (old method names):**
```typescript
const { data } = await apideck.crm.contactsAll({ serviceId: "salesforce" });
```

## Environment variables

Common Apideck env var names to search for:
```text
APIDECK_API_KEY
APIDECK_APP_ID
APIDECK_CONSUMER_ID
APIDECK_SERVICE_ID
```

## HTTP / curl

**Base URL:** `https://unify.apideck.com`

**Headers to detect:**
```text
x-apideck-app-id: ...
x-apideck-consumer-id: ...
x-apideck-service-id: ...
```

## Vault (connection management)

**Vault session creation (server-side):**
```typescript
const { data } = await apideck.vault.sessions.create({
  consumerId: "user_123",
  redirectUri: "https://yourapp.com/callback",
});
// data.session_uri → redirect user here
```

**Vault JS (embedded):**
```html
<script src="https://cdn.apideck.com/vault/vault.es.js"></script>
```

Migrate to: Merge Link (`@mergeapi/react-merge-link` or vanilla JS). See `merge-onboarding` Steps 3–5.

## Package file patterns

**Python (requirements.txt / pyproject.toml):**
```text
apideck-unify>=...
apideck>=...
```

**Node (package.json):**
```json
"@apideck/unify": "^...",
"@apideck/node": "^..."
```

**Java (build.gradle / pom.xml):**
```text
com.apideck:sdk-java
```

**Go (go.mod):**
```text
github.com/apideck-libraries/sdk-go
```
