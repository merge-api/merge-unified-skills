# SDK Quickstarts

Copy-paste install + initialization + first API call for each supported SDK. All examples use **File Storage** as the category — swap to your category by replacing `filestorage` with `hris`, `ats`, `crm`, `accounting`, `ticketing`, `knowledgebase`, or `mktg`.

## Python — `MergePythonClient`

### Install

```bash
pip install MergePythonClient
```

Or with poetry:
```bash
poetry add MergePythonClient
```

### Initialize

```python
from merge import Merge

# For making Unified API calls (need both API key and account_token)
merge = Merge(
    api_key="YOUR_TEST_KEY",          # from https://app.merge.dev/keys
    account_token="ACCOUNT_TOKEN",    # from Step 5 (token exchange)
)

# For only generating link_tokens (no account_token needed yet)
merge_admin = Merge(api_key="YOUR_TEST_KEY")
```

### Generate a link_token

```python
response = merge_admin.filestorage.link_token.create(
    end_user_email_address="alice@acme.com",
    end_user_organization_name="Acme Corp",
    end_user_origin_id="user_123",
    categories=["filestorage"],
    # Optional:
    # integration="google-drive",       # pre-select a single provider
    # link_expiry_mins=30,              # max 30
)
print(response.link_token)
print(response.magic_link_url)         # email-able URL alternative to embedded Link
```

### Exchange public_token for account_token

```python
exchange = merge_admin.filestorage.account_token.retrieve(
    public_token=public_token_from_frontend,
)
account_token = exchange.account_token
# Persist: customer_record.merge_account_token = account_token
```

### List Files

```python
merge = Merge(api_key="YOUR_TEST_KEY", account_token=account_token)

page = merge.filestorage.files.list(page_size=50)
for file in page.results:
    print(f"{file.name} ({file.mime_type}, {file.size} bytes)")

# Paginate
while page.next:
    page = merge.filestorage.files.list(cursor=page.next, page_size=50)
    for file in page.results:
        print(f"{file.name}")
```

### Retrieve a single record

```python
file = merge.filestorage.files.retrieve(id="FILE_UUID")
```

### Force a sync

```python
merge.filestorage.sync_status.resync()
```

---

## Node.js / TypeScript — `@mergeapi/merge-node-client`

### Install

```bash
npm install @mergeapi/merge-node-client
# or
yarn add @mergeapi/merge-node-client
# or
pnpm add @mergeapi/merge-node-client
```

### Initialize

```typescript
import { MergeClient } from "@mergeapi/merge-node-client";

// For Unified API calls
const merge = new MergeClient({
  apiKey: "YOUR_TEST_KEY",
  accountToken: "ACCOUNT_TOKEN",
});

// For only generating link_tokens
const mergeAdmin = new MergeClient({ apiKey: "YOUR_TEST_KEY" });
```

### Generate a link_token

```typescript
const response = await mergeAdmin.filestorage.linkToken.create({
  endUserEmailAddress: "alice@acme.com",
  endUserOrganizationName: "Acme Corp",
  endUserOriginId: "user_123",
  categories: ["filestorage"],
});
console.log(response.linkToken);
console.log(response.magicLinkUrl);
```

### Exchange public_token

```typescript
const exchange = await mergeAdmin.filestorage.accountToken.retrieve(publicToken);
const accountToken = exchange.accountToken;
```

### List Files

```typescript
const page = await merge.filestorage.files.list({ pageSize: 50 });
page.results.forEach((file) => {
  console.log(`${file.name} (${file.mimeType}, ${file.size} bytes)`);
});

// Paginate
let cursor = page.next;
while (cursor) {
  const next = await merge.filestorage.files.list({ cursor, pageSize: 50 });
  next.results.forEach((file) => console.log(file.name));
  cursor = next.next;
}
```

### Async iterator helper

```typescript
for await (const file of merge.filestorage.files.list()) {
  console.log(file.name);
}
```

The Node SDK supports auto-pagination via async iterators.

---

## React — `@mergeapi/react-merge-link`

### Install

```bash
npm install @mergeapi/react-merge-link
```

### Use the hook

```tsx
import { useMergeLink } from "@mergeapi/react-merge-link";

interface Props {
  linkToken: string;
}

export function ConnectMergeButton({ linkToken }: Props) {
  const { open, isReady } = useMergeLink({
    linkToken,
    onSuccess: async (publicToken) => {
      // Send publicToken to your backend immediately
      const res = await fetch("/api/merge/exchange", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ publicToken }),
      });
      if (!res.ok) throw new Error("Token exchange failed");
    },
    onExit: () => {
      console.log("User closed Merge Link");
    },
    onValidationError: (error) => {
      console.error("Merge Link validation error:", error);
    },
  });

  return (
    <button onClick={open} disabled={!isReady}>
      Connect your account
    </button>
  );
}
```

### Backend exchange handler (Express example)

```typescript
import express from "express";
import { MergeClient } from "@mergeapi/merge-node-client";

const merge = new MergeClient({ apiKey: process.env.MERGE_API_KEY! });

app.post("/api/merge/exchange", async (req, res) => {
  const { publicToken } = req.body;
  const { accountToken } = await merge.filestorage.accountToken.retrieve(publicToken);
  // Save accountToken keyed to req.user.id
  await db.users.update(req.user.id, { mergeAccountToken: accountToken });
  res.json({ ok: true });
});
```

---

## Java / Kotlin — `dev.merge:merge-java-client`

The JVM SDK. Works with Java and Kotlin projects.

### Install

**Gradle:**
```groovy
dependencies {
    implementation 'dev.merge:merge-java-client'
}
```

**Maven:**
```xml
<dependency>
    <groupId>dev.merge</groupId>
    <artifactId>merge-java-client</artifactId>
    <version>5.0.1</version>
</dependency>
```

Check https://github.com/merge-api/merge-java-client/releases for the latest version.

### Initialize

```java
import com.merge.api.MergeApiClient;

// For Unified API calls
MergeApiClient client = MergeApiClient.builder()
    .apiKey("YOUR_TEST_KEY")
    .accountToken("ACCOUNT_TOKEN")
    .build();

// For only generating link_tokens (no account_token needed yet)
MergeApiClient adminClient = MergeApiClient.builder()
    .apiKey("YOUR_TEST_KEY")
    .build();
```

### List Files

```java
var files = client.filestorage().files().list();
for (var file : files) {
    System.out.println(file.getName() + " (" + file.getMimeType() + ")");
}
```

The Java SDK returns a `SyncPagingIterable` — iterate directly with a for-each loop. Pagination is handled automatically.

---

## Go — `github.com/merge-api/merge-go-client`

### Install

```bash
go get github.com/merge-api/merge-go-client/v2
```

### Initialize

```go
import (
    mergeclient "github.com/merge-api/merge-go-client/v2/client"
    "github.com/merge-api/merge-go-client/v2/option"
)

client := mergeclient.NewClient(
    option.WithApiKey("YOUR_TEST_KEY"),
    option.WithAccountToken("ACCOUNT_TOKEN"),
)
```

### List Employees

```go
import (
    "context"
    "github.com/merge-api/merge-go-client/v2/hris"
)

employeeList, err := client.Hris.Employees.List(
    context.TODO(),
    &hris.EmployeesListRequest{},
)
if err != nil {
    log.Fatal(err)
}
for _, emp := range employeeList.Results {
    fmt.Printf("%s %s\n", emp.FirstName, emp.LastName)
}
```

### Paginate

```go
cursor := employeeList.Next
for cursor != nil {
    page, err := client.Hris.Employees.List(
        context.TODO(),
        &hris.EmployeesListRequest{Cursor: cursor},
    )
    if err != nil {
        log.Fatal(err)
    }
    for _, emp := range page.Results {
        fmt.Println(emp.FirstName)
    }
    cursor = page.Next
}
```

---

## Ruby — `merge_ruby_client`

### Install

```bash
gem install merge_ruby_client
```

Or in your Gemfile:
```ruby
gem "merge_ruby_client"
```

### Initialize

```ruby
require "merge_ruby_client"

# For Unified API calls
client = Merge::Client.new(
  api_key: "YOUR_TEST_KEY",
  account_token: "ACCOUNT_TOKEN"
)

# For only generating link_tokens
admin_client = Merge::Client.new(api_key: "YOUR_TEST_KEY")
```

### List Employees

```ruby
page = client.hris.employees.list
page.results.each do |emp|
  puts "#{emp.first_name} #{emp.last_name} — #{emp.work_email}"
end
```

### Retrieve a single record

```ruby
employee = client.hris.employees.retrieve(id: "EMPLOYEE_UUID")
```

---

## C# / .NET — `Merge.Client`

### Install

```bash
dotnet add package Merge.Client
```

Or via NuGet Package Manager:
```
Install-Package Merge.Client
```

### Initialize

```csharp
using Merge.Client;

// For Unified API calls
var client = new MergeClient("YOUR_TEST_KEY", "ACCOUNT_TOKEN");

// For only generating link_tokens
var adminClient = new MergeClient("YOUR_TEST_KEY");
```

### List Employees

```csharp
var employees = await client.Hris.Employees.ListAsync(new EmployeesListRequest());
foreach (var emp in employees.Results)
{
    Console.WriteLine($"{emp.FirstName} {emp.LastName}");
}
```

### Retrieve a single record

```csharp
var employee = await client.Hris.Employees.RetrieveAsync(
    "EMPLOYEE_UUID",
    new EmployeesRetrieveRequest { IncludeRemoteData = true }
);
```

---

## Vanilla HTTP (curl) — useful for testing without an SDK

### Generate link_token

```bash
curl -X POST https://api.merge.dev/api/integrations/create-link-token \
  -H "Authorization: Bearer YOUR_TEST_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "end_user_email_address": "alice@acme.com",
    "end_user_organization_name": "Acme Corp",
    "end_user_origin_id": "user_123",
    "categories": ["filestorage"]
  }'
```

### Exchange public_token

```bash
curl https://api.merge.dev/api/integrations/account-token/PUBLIC_TOKEN_HERE \
  -H "Authorization: Bearer YOUR_TEST_KEY"
```

### Make a Unified API call

```bash
curl https://api.merge.dev/api/filestorage/v1/files \
  -H "Authorization: Bearer YOUR_TEST_KEY" \
  -H "X-Account-Token: ACCOUNT_TOKEN_HERE"
```

The base API path is `/api/{category}/v1/`. Categories: `hris`, `ats`, `accounting`, `ticketing`, `crm`, `mktg`, `filestorage`, `knowledgebase`.

## SDK feature parity table

| Feature | Python | Node | Java | Go | Ruby | C# |
|---------|:------:|:----:|:----:|:--:|:----:|:--:|
| Sync API | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Async API | ✅ | ✅ (native) | ✅ | ✅ (goroutines) | ❌ | ✅ (async/await) |
| Auto-pagination | ❌ (manual) | ✅ (async iterator) | ❌ (manual) | ❌ (manual) | ❌ (manual) | ❌ (manual) |
| Type hints / generics | ✅ | ✅ (TS) | ✅ | ✅ | ❌ | ✅ |
| Webhook signature helper | ❌ (use `hmac` stdlib) | ❌ (use `crypto`) | ❌ | ❌ | ❌ | ❌ |
| Retries on 429/5xx | ✅ (configurable) | ✅ (configurable) | ✅ (configurable) | ✅ | ✅ | ✅ |

For Node, prefer the async iterator pattern. All other languages require manual pagination loops (fetch page, check `next` cursor, repeat).
