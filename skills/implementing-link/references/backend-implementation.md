# Merge Backend Implementation Guide

## API Endpoint Architecture

### Core Backend Flow
Backend handles the server-side portion of Merge's 3-step authentication flow and ongoing API operations.

**Flow Overview:**
1. **Link Token Creation**: Generate single-use tokens for modal initialization
2. **Public Token Exchange**: Convert frontend tokens to permanent account tokens  
3. **Account Management**: Handle integration lifecycle and data operations

### Database Schema

#### MergeLinkedAccount Model
```python
class MergeLinkedAccount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    end_user_origin_id = db.Column(db.String(100), nullable=False, unique=True)
    category = db.Column(db.String(50), nullable=False)  # 'hris', 'ats', 'crm', etc.
    integration_name = db.Column(db.String(100))         # 'BambooHR', 'Workday', etc.
    account_token = db.Column(db.String(500))            # Permanent API token
    status = db.Column(db.String(20), default='pending') # 'pending', 'active', 'error'
    is_active = db.Column(db.Boolean, default=True)
    last_sync = db.Column(db.DateTime)
    
    # Sync tracking columns (critical for initial sync detection)
    last_sync_time = db.Column(db.DateTime)              # For incremental sync with modified_after
    sync_status = db.Column(db.String(20))               # SYNCING, DONE, FAILED, etc. (from Merge API)
    initial_sync_completed = db.Column(db.Boolean, default=False)  # Flag for first sync completion
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', backref='merge_linked_accounts')
```

**Critical Schema Decisions:**
- **end_user_origin_id**: Must be unique and deterministic (format depends on chosen strategy)
- **Immediate Creation**: Record created during link token generation, not completion
- **Multi-Category Support**: Single organization can have integrations across different categories
- **Strategy-Dependent**: Schema constraints vary by End User Origin ID strategy (see Architecture Patterns below)

## API Endpoint Implementations

### 1. Link Token Creation

#### Endpoint: `POST /api/merge/create-link-token`
```python
@app.route('/api/merge/create-link-token', methods=['POST'])
@login_required
def create_link_token():
    try:
        data = request.get_json()
        category = data.get('category', 'hris')  # hris, ats, crm, accounting, ticketing, filestorage, knowledgebase
        integration = data.get('integration')    # Optional: for single integration mode (e.g., 'bamboohr', 'workday')
        
        # Generate end_user_origin_id based on chosen strategy
        # Strategy 1 (One per category): f"{organization_id}_{category}"
        # Strategy 2 (Multiple per category): f"{organization_id}_{category}_{integration_slug}"
        # Strategy 3 (Multiple instances): f"{organization_id}_{integration_slug}_{instance_id}"
        end_user_origin_id = generate_end_user_origin_id(current_user.id, category, data)
        
        # Check for existing integration in this category
        existing = MergeLinkedAccount.query.filter_by(
            end_user_origin_id=end_user_origin_id,
            is_active=True
        ).first()
        
        if existing and existing.status == 'active':
            return jsonify({
                'success': False,
                'error': f'Active {category} integration already exists'
            }), 400
        
        # Create or update database record IMMEDIATELY to prevent Merge conflicts
        if not existing:
            merge_account = MergeLinkedAccount(
                user_id=current_user.id,
                end_user_origin_id=end_user_origin_id,
                category=category,
                status='pending'
            )
            db.session.add(merge_account)
        else:
            # Reset existing record for fresh attempt
            existing.status = 'pending'
            existing.account_token = None
            existing.integration_name = None
            
        db.session.commit()
        
        # Generate link token from Merge API
        link_token = generate_merge_link_token(end_user_origin_id, category, integration)
        
        return jsonify({
            'success': True,
            'link_token': link_token
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

#### Link Token Generation Function
```python
def generate_merge_link_token(end_user_origin_id, category, integration=None,
                              end_user_email_address=None,
                              end_user_organization_name=None):
    """Generate fresh link token for Merge Link modal"""
    url = f"https://api.merge.dev/api/{category}/v1/link-token"
    
    headers = {
        'Authorization': f'Bearer {os.getenv("MERGE_API_KEY")}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'end_user_origin_id': end_user_origin_id,
        'end_user_email_address': end_user_email_address or current_user.email,
        'end_user_organization_name': end_user_organization_name or current_user.organization_name,
        'categories': [category]
    }
    
    # Add integration parameter for single integration mode (App Center)
    if integration:
        payload['integration'] = integration
    
    response = requests.post(url, headers=headers, json=payload)
    response.raise_for_status()
    
    return response.json()['link_token']
```

⚠️ **`end_user_email_address` and `end_user_organization_name` are required, not optional.** The link-token request body requires all four of `categories`, `end_user_origin_id`, `end_user_email_address`, and `end_user_organization_name`; omitting either of the latter two returns a `400`. Both are identification-only — setting the email address does not cause Merge to send any mail — and both cap at 100 characters.

### 2. Public Token Exchange

#### Endpoint: `POST /api/merge/exchange-public-token`
```python
@app.route('/api/merge/exchange-public-token', methods=['POST'])
@login_required
def exchange_public_token():
    try:
        data = request.get_json()
        public_token = data.get('public_token')
        
        if not public_token:
            return jsonify({
                'success': False,
                'error': 'Missing public_token'
            }), 400
        
        # Exchange public token for account token
        account_token = retrieve_account_token(public_token)
        
        # Get integration details using the new account token
        account_details = get_account_details(account_token)
        
        # Find the pending integration record
        end_user_origin_id = account_details.get('end_user_origin_id')
        merge_account = MergeLinkedAccount.query.filter_by(
            end_user_origin_id=end_user_origin_id,
            user_id=current_user.id
        ).first()
        
        if not merge_account:
            return jsonify({
                'success': False,
                'error': 'Integration record not found'
            }), 404

        # Update record with integration details
        merge_account.account_token = account_token
        merge_account.integration_name = account_details.get('integration')  # "BambooHR", "Officient", etc.
        merge_account.integration_slug = account_details.get('integration_slug')  # "bamboohr", "officient", etc.
        merge_account.status = 'active'
        merge_account.last_sync = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'integration_name': merge_account.integration_name
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

#### Token Exchange Functions
```python
def retrieve_account_token(public_token, category='hris'):
    """Exchange public_token for permanent account_token"""
    url = f"https://api.merge.dev/api/{category}/v1/account-token/{public_token}"
    
    headers = {
        'Authorization': f'Bearer {os.getenv("MERGE_API_KEY")}',
        'Content-Type': 'application/json'
    }
    
    response = requests.post(url, headers=headers)
    response.raise_for_status()
    
    return response.json()['account_token']

def get_account_details(account_token, category='hris'):
    """Retrieve integration details using account token"""
    url = f"https://api.merge.dev/api/{category}/v1/account-details"

    headers = {
        'Authorization': f'Bearer {os.getenv("MERGE_API_KEY")}',
        'X-Account-Token': account_token
    }

    response = requests.get(url, headers=headers)
    response.raise_for_status()

    return response.json()
```

**Important: Account Details Response Structure**

The `account-details` endpoint returns integration information at the **top level** of the response, not nested:

```json
{
  "id": "746ef4c0-5dbf-4999-89dd-ebc623cf3c1e",
  "integration": "Officient",           // STRING (integration name)
  "integration_slug": "officient",      // STRING (integration identifier)
  "category": "hris",
  "end_user_origin_id": "67f452a4-493c-414a-9f09-0873c003701e_hris",
  "end_user_organization_name": "Acme Corp",
  "end_user_email_address": "customer@example.com",
  "status": "COMPLETE",
  "webhook_listener_url": "https://api.merge.dev/api/integrations/webhook-listener/...",
  "is_duplicate": null,
  "account_type": "TEST",
  "completed_at": "2025-10-22T22:45:17.910266Z"
}
```

**Common Mistake**: Do NOT treat `integration` as a nested object:
```python
# ❌ WRONG - This will cause errors
integration_name = account_details['integration']['name']  # ERROR: str has no attribute 'name'

# ✅ CORRECT - Extract from top level
integration_name = account_details.get('integration')       # "Officient"
integration_slug = account_details.get('integration_slug')  # provider slug string
```

> **SDK type warning:** When using the Merge SDK (not raw HTTP), `account_token_response.integration` is an SDK model object (use `.name` for the string), but `account_details.integration` is a plain string. They are different types despite the same field name. Don't pass SDK model objects directly to `jsonify()` or `JSON.stringify()` — use `.model_dump()` (Python) or spread `{ ...obj }` (Node) to serialize.

### 3. Integration Relinking

#### Endpoint: `POST /api/merge/relink-integration`
```python
@app.route('/api/merge/relink-integration', methods=['POST'])
@login_required
def relink_integration():
    try:
        data = request.get_json()
        integration_id = data.get('integration_id')
        
        # Find the existing integration
        merge_account = MergeLinkedAccount.query.filter_by(
            id=integration_id,
            user_id=current_user.id
        ).first()
        
        if not merge_account:
            return jsonify({
                'success': False,
                'error': 'Integration not found'
            }), 404
        
        # Generate relink token using existing end_user_origin_id
        link_token = generate_merge_link_token(
            merge_account.end_user_origin_id,
            merge_account.category
        )
        
        return jsonify({
            'success': True,
            'link_token': link_token
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

### 4. Integration Deletion

#### Endpoint: `POST /api/merge/delete-integration`
```python
@app.route('/api/merge/delete-integration', methods=['POST'])
@login_required
def delete_integration():
    try:
        data = request.get_json()
        integration_id = data.get('integration_id')
        
        # Find the integration to delete
        merge_account = MergeLinkedAccount.query.filter_by(
            id=integration_id,
            user_id=current_user.id
        ).first()
        
        if not merge_account:
            return jsonify({
                'success': False,
                'error': 'Integration not found'
            }), 404
        
        # Delete from Merge's system first
        delete_account_from_merge(merge_account.account_token, merge_account.category)
        
        # Remove from local database
        db.session.delete(merge_account)
        db.session.commit()
        
        return jsonify({'success': True})
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

#### Account Deletion Function
```python
def delete_account_from_merge(account_token, category):
    """Delete account from Merge's system using POST method"""
    url = f"https://api.merge.dev/api/{category}/v1/delete-account"
    
    headers = {
        'Authorization': f'Bearer {os.getenv("MERGE_API_KEY")}',
        'X-Account-Token': account_token,
        'Content-Type': 'application/json'
    }
    
    # POST method, not DELETE
    response = requests.post(url, headers=headers)
    response.raise_for_status()
    
    return response.json()
```

## Data Syncing Implementation

### Hybrid Sync Strategy
Combine webhooks for real-time updates with polling for reliability.

#### Webhook Endpoint
```python
@app.route('/api/merge/webhook/<category>', methods=['POST'])
def handle_merge_webhook(category):
    try:
        # Verify webhook authenticity (implement signature verification)
        payload = request.get_json()
        account_token = request.headers.get('X-Account-Token')
        
        # Find the associated integration
        merge_account = MergeLinkedAccount.query.filter_by(
            account_token=account_token,
            category=category
        ).first()
        
        if not merge_account:
            return jsonify({'error': 'Integration not found'}), 404
        
        # Process webhook data
        event_type = payload.get('event_type')
        model_name = payload.get('model_name')
        
        if event_type in ['CREATE', 'UPDATE', 'DELETE']:
            sync_data_for_integration(merge_account, model_name, payload.get('data'))
            
        # Update last sync timestamp
        merge_account.last_sync = datetime.utcnow()
        db.session.commit()
        
        return jsonify({'status': 'processed'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

#### Polling Backup Implementation
```python
def sync_all_active_integrations():
    """Backup sync via polling - run every 24 hours"""
    active_integrations = MergeLinkedAccount.query.filter_by(
        status='active',
        is_active=True
    ).all()
    
    for integration in active_integrations:
        try:
            sync_integration_data(integration)
            integration.last_sync = datetime.utcnow()
            db.session.commit()
            
        except Exception as e:
            print(f"Sync failed for integration {integration.id}: {str(e)}")
            # Don't mark as failed - could be temporary network issue
            continue

def sync_integration_data(merge_account):
    """Sync data for a specific integration"""
    category = merge_account.category
    account_token = merge_account.account_token
    
    if category == 'hris':
        # Sync employees, departments, etc.
        sync_hris_employees(account_token)
        sync_hris_departments(account_token)
    elif category == 'ats':
        # Sync candidates, jobs, etc.
        sync_ats_candidates(account_token)
        sync_ats_jobs(account_token)
    elif category == 'crm':
        # Sync contacts, accounts, etc.
        sync_crm_contacts(account_token)
        sync_crm_accounts(account_token)
    elif category == 'accounting':
        # Sync invoices, payments, etc.
        sync_accounting_invoices(account_token)
        sync_accounting_payments(account_token)
    elif category == 'ticketing':
        # Sync tickets, users, etc.
        sync_ticketing_tickets(account_token)
        sync_ticketing_users(account_token)
    elif category == 'filestorage':
        # Sync files, folders, permissions, etc.
        sync_filestorage_files(account_token)
        sync_filestorage_folders(account_token)
    elif category == 'knowledgebase':
        # Sync articles, spaces, pages, etc.
        sync_knowledgebase_articles(account_token)
        sync_knowledgebase_spaces(account_token)
```

### Initial Sync Detection and Management

**CRITICAL CONCEPT**: After authentication completes, Merge begins an "initial sync" process to normalize data from the 3rd party system. Your application must detect when this process completes before attempting to retrieve normalized data.

#### Why Initial Sync Detection Matters
- **Data Completeness**: Merge APIs may return partial data during initial sync, but this represents incomplete datasets that shouldn't be used for business logic
- **User Experience**: Users expect immediate access but need proper expectation setting about data completeness
- **Reliable Architecture**: Polling sync status prevents retrieval of incomplete datasets during initial normalization

#### Database Schema Requirements
The sync tracking columns added to `MergeLinkedAccount` are essential:

```python
# Sync tracking columns (add to existing model)
last_sync_time = db.Column(db.DateTime)              # Timestamp when data retrieval STARTED (for modified_after param)
sync_status = db.Column(db.String(20))               # SYNCING, DONE, FAILED, etc. (from Merge API)
initial_sync_completed = db.Column(db.Boolean, default=False)  # Flag for first sync completion
```

#### Sync Status Checking with MergePythonSDK

```python
from MergePythonSDK.shared.api_client import ApiClient
from MergePythonSDK.shared.configuration import Configuration
from MergePythonSDK.hris.api.sync_status_api import SyncStatusApi

def check_sync_status(account_token, category, api_key):
    """Check sync status for all models in a category using MergePythonSDK"""
    try:
        # Configure API client
        configuration = Configuration()
        configuration.api_key['Authorization'] = f'Bearer {api_key}'
        configuration.api_key['X-Account-Token'] = account_token
        
        api_client = ApiClient(configuration)
        
        if category == 'hris':
            sync_api = SyncStatusApi(api_client)
            sync_statuses = sync_api.sync_status_list()
        else:
            logging.error(f"Category {category} not implemented yet")
            return None
        
        return sync_statuses
    except Exception as e:
        logging.error(f"Error checking sync status: {str(e)}")
        return None

def is_initial_sync_complete(sync_statuses):
    """Check if initial sync is complete for all enabled models"""
    if not sync_statuses or not sync_statuses.results:
        return False
    
    for model in sync_statuses.results:
        if model.status == "DISABLED":
            continue  # Skip disabled models
        
        # If any enabled model is still syncing, initial sync not complete
        if model.status == "SYNCING":
            return False
        
        # If any enabled model failed, return False (could raise error instead)
        if model.status in ["FAILED", "PAUSED"]:
            return False
    
    # All enabled models are DONE - initial sync complete!
    return True

def get_latest_sync_time(sync_statuses):
    """Get the latest sync finished time from all enabled models"""
    latest_time = None
    
    if not sync_statuses or not sync_statuses.results:
        return None
    
    for model in sync_statuses.results:
        if model.status == "DISABLED" or not model.last_sync_finished:
            continue
        
        from datetime import datetime
        sync_time = datetime.fromisoformat(model.last_sync_finished.replace('Z', '+00:00'))
        
        if latest_time is None or sync_time > latest_time:
            latest_time = sync_time
    
    return latest_time
```

#### Sync Status API Endpoint

```python
@app.route('/api/merge/check-sync-status', methods=['POST'])
@login_required
def check_integration_sync_status():
    """Check and update sync status for user's integrations"""
    try:
        data = request.get_json()
        integration_id = data.get('integration_id')
        
        if not integration_id:
            return jsonify({'success': False, 'error': 'Integration ID required'}), 400
        
        # Get the integration
        integration = MergeLinkedAccount.query.filter_by(
            id=integration_id,
            user_id=current_user.id,
            is_active=True
        ).first()
        
        if not integration:
            return jsonify({'success': False, 'error': 'Integration not found'}), 404
        
        # Check current sync status via Merge API
        sync_statuses = check_sync_status(
            integration.account_token, 
            integration.category, 
            os.getenv('MERGE_API_KEY')
        )
        
        if not sync_statuses:
            return jsonify({'success': False, 'error': 'Unable to check sync status'}), 500
        
        # Update database with current status
        is_complete = is_initial_sync_complete(sync_statuses)
        latest_sync = get_latest_sync_time(sync_statuses)
        
        # Determine overall sync status
        if is_complete:
            if not integration.initial_sync_completed:
                integration.initial_sync_completed = True
                integration.sync_status = 'DONE'
                logging.info(f"Initial sync completed for integration {integration.id}")
            integration.last_sync_time = latest_sync
        else:
            integration.sync_status = 'SYNCING'
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'sync_complete': is_complete,
            'sync_status': integration.sync_status,
            'last_sync_time': latest_sync.isoformat() if latest_sync else None
        })
        
    except Exception as e:
        logging.error(f"Error checking sync status: {str(e)}")
        return jsonify({'success': False, 'error': 'Internal server error'}), 500
```

#### Sample Sync Status API Response

**Initial Sync (SYNCING):**
```json
{
  "model": "hris.employees",
  "model_name": "Employee",
  "status": "SYNCING",
  "is_initial_sync": true,
  "last_sync_started": "2024-01-15T10:30:00Z",
  "last_sync_finished": null
}
```

**Initial Sync Complete (DONE):**
```json
{
  "model": "hris.employees", 
  "model_name": "Employee",
  "status": "DONE",
  "is_initial_sync": false,
  "last_sync_started": "2024-01-15T10:30:00Z",
  "last_sync_finished": "2024-01-15T10:35:00Z"
}
```

#### Key Implementation Insights

**Critical Timing**: The `is_initial_sync` flag flips to `false` immediately upon first completion, not after a second sync.

**When Data is Ready to Fetch**: Poll `/sync-status` until **EITHER** condition is true:
- `status == "DONE"` OR `status == "PARTIALLY_SYNCED"`, **OR**
- `is_initial_sync == false`

**Why Use OR Logic**:
- Using **OR** (not AND) ensures you catch data readiness regardless of timing
- `status == "DONE"` catches the moment sync completes
- `is_initial_sync == false` catches it if you poll after sync already completed
- Both signals indicate data is ready, use whichever you detect first

**Status Values**:
1. **SYNCING**: Initial sync in progress - data may be partially available but incomplete
2. **DONE**: Sync completed successfully - full dataset ready for retrieval
3. **PARTIALLY_SYNCED**: Some data synced, enough for retrieval
4. **FAILED/PAUSED**: Sync encountered issues - requires attention
5. **DISABLED**: Model not enabled for this integration

**User Experience Patterns**:
- Set clear expectations: "Initial sync in progress, check back in a few minutes"
- Provide manual refresh capability for checking sync status
- Show different UI states based on `initial_sync_completed` flag

#### Frontend Integration Example

```javascript
function checkSyncStatus(integrationId) {
    fetch('/api/merge/check-sync-status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ integration_id: integrationId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            if (data.sync_complete) {
                // Update UI to show "Sync complete" 
                // Now safe to retrieve normalized data
                showSyncComplete();
            } else {
                // Show "Initial sync in progress"
                showSyncInProgress();
            }
        }
    });
}
```

**When to Trigger Data Retrieval**: Only call Merge's data endpoints (employees, companies, etc.) AFTER `is_initial_sync_complete()` returns `true`. While partial data may be available during the SYNCING state, this ensures you're retrieving the complete, fully normalized dataset rather than incomplete records.

### Incremental Data Sync with modified_after

After initial sync completes, use the `modified_after` parameter for efficient incremental updates.

#### Key Pattern: Store Start Time, Not End Time

**Critical**: Always store the timestamp when you START pulling data, not when you finish. This ensures no records are missed between sync operations.

```python
def sync_employees_incremental(account_token, last_sync_time=None):
    """Sync employees using modified_after for incremental updates"""
    
    # Record when we START this sync operation
    sync_start_time = datetime.utcnow()
    
    # Build API URL with modified_after parameter
    url = f"{MERGE_API_BASE}/hris/v1/employees"
    params = {}
    
    if last_sync_time:
        # Use ISO format for modified_after parameter
        params['modified_after'] = last_sync_time.isoformat()
    
    headers = {
        'Authorization': f'Bearer {MERGE_API_KEY}',
        'X-Account-Token': account_token
    }
    
    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        
        # Process the employee data
        for employee_data in data.get('results', []):
            process_employee_record(employee_data)
        
        # IMPORTANT: Update last_sync_time with START time, not current time
        integration = MergeLinkedAccount.query.filter_by(account_token=account_token).first()
        integration.last_sync_time = sync_start_time
        db.session.commit()
        
        return True
        
    except Exception as e:
        logging.error(f"Error syncing employees: {str(e)}")
        return False
```

#### Example API Usage Patterns

**Initial Sync (no modified_after)**:
```text
GET /hris/v1/employees
```

**Incremental Sync (with modified_after)**:
```text
GET /hris/v1/employees?modified_after=2024-01-15T10:30:00Z
```

**Multi-Model Incremental Sync**:
```python
def sync_all_hris_data_incremental(integration):
    """Sync all HRIS models incrementally"""
    last_sync = integration.last_sync_time
    
    # Sync all models with same timestamp
    sync_employees_incremental(integration.account_token, last_sync)
    sync_departments_incremental(integration.account_token, last_sync)
    sync_companies_incremental(integration.account_token, last_sync)
    
    # All models use same start timestamp for consistency
```

#### Why Start Time vs End Time Matters

**Problem with End Time**: If you store when sync finishes, records modified during the sync operation could be missed in the next sync.

**Solution with Start Time**: Using the start timestamp ensures complete coverage with potential overlap (which is safer than gaps).

```text
Sync 1: Start 10:00, End 10:05, Store: 10:00
Sync 2: modified_after=10:00, Start 10:15, End 10:18, Store: 10:15
```

Records modified between 10:00-10:05 are captured in both syncs (safe overlap) rather than potentially missed.

#### Ongoing Sync Status Monitoring

**Continue polling `/sync-status`** even after initial sync completes to detect when new data is available.

```python
def should_sync_data(integration):
    """Determine if data sync is needed based on current sync status"""
    
    # Always check current sync status first
    sync_statuses = check_sync_status(
        integration.account_token, 
        integration.category, 
        os.getenv('MERGE_API_KEY')
    )
    
    if not sync_statuses:
        return False, "Unable to check sync status"
    
    # Check if any models have data available
    has_data_available = False
    for model in sync_statuses.results:
        if model.status in ["DONE", "PARTIALLY_SYNCED"]:
            has_data_available = True
            break
    
    return has_data_available, "Data available for sync"

def sync_data_if_needed(integration):
    """Smart sync that only pulls data when needed"""
    
    should_sync, reason = should_sync_data(integration)
    
    if not should_sync:
        logging.info(f"Skipping sync for integration {integration.id}: {reason}")
        return
    
    # Get last sync time for modified_after parameter
    last_sync = integration.last_sync_time
    
    if not last_sync:
        # First time syncing - no modified_after needed
        logging.info(f"Performing initial data sync for integration {integration.id}")
        sync_employees_incremental(integration.account_token)
    else:
        # Delta sync with modified_after
        logging.info(f"Performing incremental sync since {last_sync}")
        sync_employees_incremental(integration.account_token, last_sync)
```

#### Efficiency Benefits of modified_after

**Without modified_after** (inefficient):
```text
GET /hris/v1/employees
→ Returns all 500 employees every time
→ Wastes bandwidth and processing
→ No indication of what actually changed
```

**With modified_after** (efficient):
```text
GET /hris/v1/employees?modified_after=2024-01-15T10:30:00Z
→ Returns only 3 employees that changed since last sync
→ Minimal bandwidth and processing
→ Clear delta of actual changes
```

#### Sync Status Response Handling

**Key Status Values for Ongoing Syncs**:
- **`DONE`**: Sync completed, data ready for retrieval
- **`PARTIALLY_SYNCED`**: Some data available, safe to retrieve current delta
- **`SYNCING`**: New sync in progress, may want to wait or proceed based on business needs

**When No New Data Available**:
If Merge hasn't started a new sync since your last data pull, the `modified_after` query will return empty results - this is expected and efficient behavior.

```python
def handle_incremental_sync_response(response_data, integration):
    """Handle response from incremental sync API call"""
    
    results = response_data.get('results', [])
    
    if not results:
        logging.info(f"No new data since {integration.last_sync_time} - sync up to date")
        return True  # Success, just no changes
    
    logging.info(f"Processing {len(results)} changed records since last sync")
    
    # Process only the delta records
    for record in results:
        process_record(record)
    
    return True
```

This pattern ensures you're only processing actual changes while maintaining real-time awareness of when new data becomes available through continuous sync-status monitoring.

## Error Handling Patterns

### Retry Logic with Exponential Backoff
```python
import time
import random

def make_merge_request_with_retry(url, headers, payload=None, max_retries=3):
    """Make Merge API request with exponential backoff retry"""
    for attempt in range(max_retries + 1):
        try:
            if payload:
                response = requests.post(url, headers=headers, json=payload)
            else:
                response = requests.get(url, headers=headers)
                
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            if attempt == max_retries:
                raise e
                
            # Exponential backoff with jitter
            delay = (2 ** attempt) + random.uniform(0, 1)
            time.sleep(delay)
```

### Integration Health Monitoring
```python
def check_integration_health(merge_account):
    """Verify integration is still active and healthy"""
    try:
        account_details = get_account_details(
            merge_account.account_token,
            merge_account.category
        )

        # Update integration info in case it changed
        if account_details.get('integration'):
            merge_account.integration_name = account_details['integration']  # String value
            merge_account.integration_slug = account_details.get('integration_slug')
        
        merge_account.status = 'active'
        db.session.commit()
        return True
        
    except requests.exceptions.HTTPError as e:
        if e.response.status_code in [401, 403]:
            # Authentication failed - integration needs relinking
            merge_account.status = 'error'
            db.session.commit()
            
        return False
```

## Environment Configuration

### Required Environment Variables
```python
# .env file requirements
MERGE_API_KEY="your_merge_api_key_here"           # From Merge dashboard
DATABASE_URL="postgresql://..."                   # Database connection
SESSION_SECRET="your_session_secret"              # Flask session encryption

# Optional webhook configuration
MERGE_WEBHOOK_SECRET="webhook_signature_secret"   # For webhook verification
```

### API Key Management
```python
import os
from functools import wraps

def require_merge_api_key(f):
    """Decorator to ensure Merge API key is available"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not os.getenv('MERGE_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'Merge API key not configured'
            }), 500
        return f(*args, **kwargs)
    return decorated_function

# Usage
@app.route('/api/merge/create-link-token', methods=['POST'])
@login_required
@require_merge_api_key
def create_link_token():
    # Implementation here
    pass
```

## Testing Strategy

### Unit Tests for Multi-Category Token Operations
```python
import unittest
from unittest.mock import patch, Mock

class TestMergeIntegration(unittest.TestCase):
    
    @patch('requests.post')
    def test_generate_link_token_success(self, mock_post):
        mock_response = Mock()
        mock_response.json.return_value = {'link_token': 'test_token_123'}
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response
        
        token = generate_merge_link_token('user_1_hris', 'hris')
        
        self.assertEqual(token, 'test_token_123')
        mock_post.assert_called_once()
    
    def test_end_user_origin_id_format_multiple_categories(self):
        user_id = 42
        test_cases = [
            ('hris', 'user_42_hris'),
            ('ats', 'user_42_ats'),
            ('crm', 'user_42_crm'),
            ('accounting', 'user_42_accounting'),
            ('ticketing', 'user_42_ticketing'),
            ('filestorage', 'user_42_filestorage'),
            ('knowledgebase', 'user_42_knowledgebase')
        ]
        
        for category, expected in test_cases:
            result = f"{user_id}_{category}"
            self.assertEqual(result, expected)
```

### Integration Health Checks
```python
def run_integration_health_check():
    """Manual health check for all active integrations"""
    active_integrations = MergeLinkedAccount.query.filter_by(
        status='active',
        is_active=True
    ).all()
    
    results = []
    for integration in active_integrations:
        health_status = check_integration_health(integration)
        results.append({
            'integration_id': integration.id,
            'integration_name': integration.integration_name,
            'user_id': integration.user_id,
            'healthy': health_status
        })
    
    return results
```

## Production Considerations

### Rate Limiting
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/merge/create-link-token', methods=['POST'])
@limiter.limit("10 per minute")  # Prevent token spam
@login_required
def create_link_token():
    # Implementation
    pass
```

### Logging and Monitoring
```python
import logging

# Configure logging for Merge operations
merge_logger = logging.getLogger('merge_integration')
merge_logger.setLevel(logging.INFO)

handler = logging.FileHandler('logs/merge_integration.log')
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
merge_logger.addHandler(handler)

def log_merge_operation(operation, user_id, details):
    """Log Merge integration operations for monitoring"""
    merge_logger.info(f"{operation} - User: {user_id} - Details: {details}")
```

### Security Best Practices
```python
# Never log sensitive tokens
def safe_log_token(token):
    """Safely log token for debugging (first 8 chars only)"""
    if token and len(token) > 8:
        return f"{token[:8]}..."
    return "invalid_token"

# Validate webhook signatures (implement based on Merge documentation)
def verify_webhook_signature(payload, signature, secret):
    """Verify webhook came from Merge"""
    import hmac
    import hashlib
    
    expected = hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected, signature)
```

## End User Origin ID Architecture Patterns

The `end_user_origin_id` generation strategy fundamentally shapes your backend implementation. Each strategy requires different database constraints, validation logic, and API patterns.

### Strategy 1: One Integration per Category

**Format**: `{organization_id}_{category}`

#### Database Schema
```python
class MergeLinkedAccount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    organization_id = db.Column(db.Integer, nullable=False)
    category = db.Column(db.String(50), nullable=False)
    end_user_origin_id = db.Column(db.String(100), nullable=False, unique=True)
    account_token = db.Column(db.String(500))
    integration_name = db.Column(db.String(100))  # "BambooHR", populated after linking
    integration_slug = db.Column(db.String(50))   # "bamboohr", populated after linking
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Enforce one integration per category per organization
    __table_args__ = (
        db.UniqueConstraint('organization_id', 'category', name='unique_org_category'),
    )
```

#### ID Generation Function
```python
def generate_end_user_origin_id(organization_id, category):
    """Strategy 1: One integration per category"""
    return f"{organization_id}_{category}"

# Example outputs:
# "org_123_hris", "org_123_ats", "org_123_crm"
```

#### Validation Logic
```python
def validate_integration_limit(organization_id, category):
    """Ensure only one integration per category"""
    existing = MergeLinkedAccount.query.filter_by(
        organization_id=organization_id,
        category=category,
        status='active'
    ).first()

    if existing:
        raise ValidationError(f"Active {category} integration already exists")
```

---

### Strategy 2: Multiple Integrations per Category

**Format**: `{organization_id}_{category}_{unique_id}`

**⚠️ CRITICAL IMPLEMENTATION DETAIL**: When implementing Strategy 2, you MUST handle incomplete linking attempts correctly to avoid cluttering your Merge dashboard with duplicate incomplete accounts. See the "Handling Incomplete Linking Attempts" section below for the required logic.

**Key Principles:**
1. **Save the `end_user_origin_id` BEFORE the user opens Merge Link** (not after)
2. **Reuse the same `end_user_origin_id` for retry attempts** when status='pending'
3. **Create NEW `end_user_origin_id` only when:**
   - First linking attempt (no existing record)
   - Adding a second integration (existing record with status='active')

#### Database Schema
```python
import uuid

class MergeLinkedAccount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    organization_id = db.Column(db.Integer, nullable=False)
    category = db.Column(db.String(50), nullable=False)
    unique_id = db.Column(db.String(100), nullable=False)  # UUID for this connection
    end_user_origin_id = db.Column(db.String(200), nullable=False, unique=True)
    account_token = db.Column(db.String(500))
    integration_name = db.Column(db.String(100))  # "BambooHR", populated after linking
    integration_slug = db.Column(db.String(50))   # "bamboohr", populated after linking
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Optional: Add display name for user-facing organization
    display_name = db.Column(db.String(100))  # "Production", "US Region", "Subsidiary A"

    # No uniqueness constraint on integration_slug - allow multiple connections
```

#### Critical: Handling Incomplete Linking Attempts

**Merge Best Practice**: When a user exits the linking flow without completing it, Merge creates an "Incomplete" account on their side. A common pitfall is generating a **new** `end_user_origin_id` for every retry attempt, which creates duplicate incomplete accounts and clutters your Merge dashboard.

**The Solution**: Save the `end_user_origin_id` at the START of the linking flow (before the user opens Merge Link), and **reuse the same ID** for retry attempts.

##### Incomplete Attempt Flow Logic

```python
def create_link_token(user, category):
    """Generate link token with proper end_user_origin_id reuse logic"""

    # Step 1: Check for existing records for this user + category
    existing_account = MergeLinkedAccount.query.filter_by(
        user_id=user.id,
        category=category
    ).order_by(MergeLinkedAccount.created_at.desc()).first()

    # Step 2: Determine whether to reuse or create new end_user_origin_id
    if existing_account and existing_account.status == 'pending':
        # SCENARIO A: Incomplete attempt - REUSE the same end_user_origin_id
        # User started linking but didn't finish. Reuse the ID to avoid duplicate incomplete accounts.
        end_user_origin_id = existing_account.end_user_origin_id
        logging.info(f"Reusing end_user_origin_id for retry: {end_user_origin_id}")

    elif existing_account and existing_account.status == 'active':
        # SCENARIO B: User already has a completed integration, wants to add another
        # This is Strategy 2 in action - create NEW UUID for the second integration
        unique_id = str(uuid.uuid4())
        end_user_origin_id = f"{user.organization_id}_{category}_{unique_id}"

        # Create new pending record for the additional integration
        new_account = MergeLinkedAccount(
            user_id=user.id,
            unique_id=unique_id,
            end_user_origin_id=end_user_origin_id,
            category=category,
            status='pending'
        )
        db.session.add(new_account)
        db.session.commit()
        logging.info(f"Adding second integration - new end_user_origin_id: {end_user_origin_id}")

    else:
        # SCENARIO C: First linking attempt - create NEW UUID
        unique_id = str(uuid.uuid4())
        end_user_origin_id = f"{user.organization_id}_{category}_{unique_id}"

        first_account = MergeLinkedAccount(
            user_id=user.id,
            unique_id=unique_id,
            end_user_origin_id=end_user_origin_id,
            category=category,
            status='pending'
        )
        db.session.add(first_account)
        db.session.commit()
        logging.info(f"First linking attempt - new end_user_origin_id: {end_user_origin_id}")

    # Step 3: Generate fresh link token with the end_user_origin_id (reused or new)
    # Link tokens expire in 30 minutes by default, so always generate a fresh token
    # But reuse the same end_user_origin_id for incomplete attempts
    link_token = generate_merge_link_token(end_user_origin_id, category)
    return link_token
```

##### Why This Matters

**Without this logic (WRONG):**
```text
User clicks "Connect" → New UUID → "pending" record created
User exits modal → Orphaned "pending" record + Incomplete account in Merge
User clicks "Connect" again → NEW UUID → NEW "pending" record created
User exits again → Another orphaned record + Another incomplete account in Merge
Result: 2 pending records in your DB, 2 incomplete accounts in Merge dashboard
```

**With this logic (CORRECT):**
```text
User clicks "Connect" → New UUID → "pending" record created
User exits modal → Record stays "pending"
User clicks "Connect" again → SAME UUID reused → Same record found
User completes linking → Existing record updated to "active"
Result: 1 clean record in your DB, 1 complete account in Merge dashboard
```

##### Visual Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                    User First Attempt                            │
└─────────────────────────────────────────────────────────────────┘
  User clicks "Connect"
       ↓
  Check database: No existing record
       ↓
  Generate NEW UUID: abc-123
  Create record: status='pending', end_user_origin_id='org_hris_abc-123'
       ↓
  Generate link token with end_user_origin_id='org_hris_abc-123'
       ↓
  User opens Merge Link modal
       ↓
  User exits without completing
       ↓
  Record remains: status='pending' ✓

┌─────────────────────────────────────────────────────────────────┐
│                    User Retry Attempt                            │
└─────────────────────────────────────────────────────────────────┘
  User clicks "Connect" again
       ↓
  Check database: Found record with status='pending'
       ↓
  REUSE EXISTING: end_user_origin_id='org_hris_abc-123' ✓
       ↓
  Generate NEW link token with SAME end_user_origin_id='org_hris_abc-123'
       ↓
  User opens Merge Link modal
       ↓
  User completes linking to BambooHR
       ↓
  Update record: status='active', integration_name='BambooHR' ✓

┌─────────────────────────────────────────────────────────────────┐
│                 User Adds Second Integration                     │
└─────────────────────────────────────────────────────────────────┘
  User clicks "Connect" again
       ↓
  Check database: Found record with status='active'
       ↓
  Generate NEW UUID: xyz-789 (Strategy 2!)
  Create NEW record: status='pending', end_user_origin_id='org_hris_xyz-789'
       ↓
  Generate link token with NEW end_user_origin_id='org_hris_xyz-789'
       ↓
  User completes linking to Workday
       ↓
  Update new record: status='active', integration_name='Workday' ✓
       ↓
  Result: 2 active integrations (BambooHR + Workday) ✓
```

##### Testing the Flow

To verify this is working correctly:

1. **First attempt**: Click "Connect HRIS Integration"
   - Check logs: `"First linking attempt - new end_user_origin_id: org_123_hris_abc..."`
   - Exit the modal without completing

2. **Retry attempt**: Click "Connect HRIS Integration" again
   - Check logs: `"Reusing end_user_origin_id for retry: org_123_hris_abc..."` (same ID!)
   - Complete the linking flow
   - Database record updates from `status='pending'` to `status='active'`

3. **Adding second integration**: Click "Connect HRIS Integration" again
   - Check logs: `"Adding second integration - new end_user_origin_id: org_123_hris_xyz..."` (NEW ID!)
   - This allows multiple integrations per category (Strategy 2)

#### ID Generation Function
```python
def generate_end_user_origin_id(organization_id, category):
    """Strategy 2: Multiple integrations per category

    NOTE: Don't call this directly in create_link_token!
    Use the logic above to check for existing pending records first.
    """
    unique_id = str(uuid.uuid4())  # Full UUID for guaranteed uniqueness
    return f"{organization_id}_{category}_{unique_id}"

# Example outputs:
# "org_123_hris_550e8400-e29b-41d4-a716-446655440000"
```

#### Complete Implementation Flow

**Important: Merge Best Practice for Incomplete Attempts**

When a user exits the linking flow without completing it, Merge creates an "Incomplete" account. To avoid cluttering your Merge dashboard with duplicate incomplete accounts, **reuse the same end_user_origin_id** for retry attempts.

```python
# Step 1: Create Link Token
@app.route('/api/merge/create-link-token', methods=['POST'])
@login_required
def create_link_token():
    try:
        data = request.get_json()
        category = data.get('category', 'hris')

        # Check for existing records for this user + category
        existing_account = MergeLinkedAccount.query.filter_by(
            user_id=current_user.id,
            category=category
        ).order_by(MergeLinkedAccount.created_at.desc()).first()

        if existing_account and existing_account.status == 'pending':
            # There's an incomplete linking attempt - REUSE the same end_user_origin_id
            # This prevents creating duplicate incomplete accounts in Merge's dashboard
            end_user_origin_id = existing_account.end_user_origin_id
            logging.info(f"Reusing existing end_user_origin_id for retry: {end_user_origin_id}")

        elif existing_account and existing_account.status == 'active':
            # User already has a completed integration and wants to add another one
            # Strategy 2: Create NEW UUID for the second integration in same category
            unique_id = str(uuid.uuid4())
            end_user_origin_id = f"{current_user.organization_id}_{category}_{unique_id}"

            # Create new pending record for the additional integration
            merge_account = MergeLinkedAccount(
                user_id=current_user.id,
                category=category,
                unique_id=unique_id,
                end_user_origin_id=end_user_origin_id,
                integration_name=None,  # Don't know yet - user will pick in Merge modal
                integration_slug=None,  # Don't know yet
                status='pending'
            )
            db.session.add(merge_account)
            db.session.commit()
            logging.info(f"Creating second integration - new end_user_origin_id: {end_user_origin_id}")

        else:
            # No existing record - this is the first linking attempt
            # Generate new UUID and create new record
            unique_id = str(uuid.uuid4())
            end_user_origin_id = f"{current_user.organization_id}_{category}_{unique_id}"

            merge_account = MergeLinkedAccount(
                user_id=current_user.id,
                category=category,
                unique_id=unique_id,
                end_user_origin_id=end_user_origin_id,
                integration_name=None,  # Don't know yet - user will pick in Merge modal
                integration_slug=None,  # Don't know yet
                status='pending'
            )
            db.session.add(merge_account)
            db.session.commit()
            logging.info(f"First linking attempt - created new end_user_origin_id: {end_user_origin_id}")

        # Generate link token from Merge (always create fresh link token, but reuse end_user_origin_id)
        link_token = generate_merge_link_token(end_user_origin_id, category)

        return jsonify({
            'success': True,
            'link_token': link_token
        })

    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Step 2: Exchange Public Token
@app.route('/api/merge/exchange-public-token', methods=['POST'])
@login_required
def exchange_public_token():
    try:
        data = request.get_json()
        public_token = data.get('public_token')

        if not public_token:
            return jsonify({
                'success': False,
                'error': 'Missing public_token'
            }), 400

        # Exchange for account_token
        account_token = retrieve_account_token(public_token)

        # Get account details to learn what they connected
        account_details = get_account_details(account_token)

        # Find the pending record
        end_user_origin_id = account_details.get('end_user_origin_id')
        merge_account = MergeLinkedAccount.query.filter_by(
            end_user_origin_id=end_user_origin_id,
            organization_id=current_user.organization_id
        ).first()

        if not merge_account:
            return jsonify({
                'success': False,
                'error': 'Integration record not found'
            }), 404

        # Update with integration details (extract from top level of response)
        merge_account.account_token = account_token
        merge_account.integration_name = account_details.get('integration')  # "BambooHR", "Officient", etc.
        merge_account.integration_slug = account_details.get('integration_slug')  # "bamboohr", "officient", etc.
        merge_account.status = 'active'

        db.session.commit()

        return jsonify({
            'success': True,
            'integration_name': merge_account.integration_name
        })

    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

---

### Strategy Selection in Code

#### Configuration-Driven Strategy
```python
class IntegrationConfig:
    # Choose your strategy: 1 or 2
    END_USER_ORIGIN_STRATEGY = 2  # 1 = one per category, 2 = multiple per category

    # Strategy-specific settings
    ALLOW_MULTIPLE_PER_CATEGORY = END_USER_ORIGIN_STRATEGY == 2

def generate_end_user_origin_id(organization_id, category):
    """Dynamic strategy selection"""
    if IntegrationConfig.END_USER_ORIGIN_STRATEGY == 1:
        return f"{organization_id}_{category}"

    elif IntegrationConfig.END_USER_ORIGIN_STRATEGY == 2:
        unique_id = str(uuid.uuid4())
        return f"{organization_id}_{category}_{unique_id}"

    else:
        raise ValueError(f"Unknown strategy: {IntegrationConfig.END_USER_ORIGIN_STRATEGY}")
```

## Key Implementation Requirements

### Critical Success Factors
1. **Strategy Decision Early**: Choose end_user_origin_id strategy before implementation
2. **Database Record Timing**: Always store end_user_origin_id immediately during link token creation
3. **Fresh Token Generation**: Never cache or reuse link tokens between attempts  
4. **Strategy-Appropriate Constraints**: Implement database constraints matching chosen strategy
5. **Multi-Category Architecture**: Support integrations across different categories
6. **Account Token Preservation**: Never change account tokens during relinking
7. **POST Method for Deletion**: Use POST, not DELETE for account deletion API
8. **Proper Error Recovery**: Reset integration states cleanly on failures

### Common Backend Mistakes
1. **Storing records too late**: Causes duplicate Merge accounts
2. **Caching link tokens**: Violates Merge's single-use requirement
3. **Wrong deletion endpoint**: Using DELETE instead of POST method
4. **Missing error handling**: Not cleaning up partial states on failures
5. **Inadequate logging**: Not tracking operations for debugging production issues