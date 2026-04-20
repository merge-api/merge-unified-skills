# Merge Frontend Implementation Guide

## Implementation Styles

### 1. Connect Integration Button (Standard)
A single button that directly opens the Merge Link modal for connecting integrations. Best for applications with focused integration needs.

**User Experience:**
- Click "Connect HRIS Integration" → Modal opens → User authenticates → Integration connected
- Simple, direct flow with minimal cognitive overhead

### 2. App Center/Integration Marketplace (Advanced) 
A comprehensive integration marketplace showing available providers with search, filtering, and categorization. Best for platforms offering many integration options across multiple categories (HRIS, ATS, CRM, Accounting, Ticketing, FileStorage, Knowledge Base).

**User Experience:**
- Browse integration catalog → Select provider → Modal opens → User authenticates → Integration connected
- Discovery-focused experience for users exploring integration options

**Key Merge Concepts:**
- **Single Integration Mode**: Skip Merge's marketplace by targeting specific integrations
- **Same Authentication Flow**: Uses identical 3-step token process as Connect Button
- **Multi-Integration State Management**: Handle connection states across multiple integration options

## Connect Integration Button Implementation

### Core User Experience Principles

#### Invisible Integration
- **Zero Merge terminology** exposed anywhere in UI
- **Business-focused messaging**: "Connect HR System" not "Connect via Merge"
- **Seamless experience** that feels native to your application
- **No technical references** to tokens, APIs, or authentication flows

#### Progressive Enhancement
- **Simple entry point**: Single prominent button
- **Clear value proposition**: "Connect your HR platform to automatically sync employee data"
- **Contextual help**: Explain benefits without technical jargon

### Frontend Architecture

#### HTML Structure
```html
<!-- Integration connection button -->
<button id="connectHRISBtn" class="btn btn-primary w-100 mb-3">
    <i data-feather="link" class="me-1"></i>Connect HRIS Integration
</button>

<!-- Merge Link SDK -->
<script src="https://cdn.merge.dev/initialize.js"></script>
```

#### JavaScript Implementation
```javascript
document.addEventListener('DOMContentLoaded', function() {
    const connectBtn = document.getElementById('connectHRISBtn');
    let mergeLinkInitialized = false;
    
    // Reset button to normal state
    function resetButton() {
        connectBtn.disabled = false;
        connectBtn.innerHTML = '<i data-feather="link" class="me-1"></i>Connect HRIS Integration';
        feather.replace();
    }
    
    // Handle successful integration completion
    function onSuccess(public_token) {
        // Send public_token to backend for exchange
        fetch('/api/merge/exchange-public-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ public_token: public_token })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Refresh page to show new integration
                window.location.reload();
            }
        });
    }
    
    // Handle modal exit/cancellation
    function onExit(error) {
        resetButton();
    }
    
    // Handle integration errors
    function onError(error) {
        console.error('Integration error:', error);
        alert('An error occurred during setup. Please try again.');
        resetButton();
    }
    
    // Initialize Merge Link with fresh token
    function initializeMergeLink(linkToken) {
        MergeLink.initialize({
            linkToken: linkToken,
            onSuccess: onSuccess,
            onExit: onExit,
            onError: onError,
            onReady: () => {
                resetButton();
                // CRITICAL: Must explicitly call openLink() to show modal
                MergeLink.openLink();
            },
            shouldSendTokenOnSuccessfulLink: true,
        });
    }
    
    // Button click handler - always generates fresh token
    connectBtn.addEventListener('click', function() {
        connectBtn.disabled = true;
        connectBtn.innerHTML = '<i data-feather="loader" class="me-1"></i>Initializing...';
        feather.replace();
        
        // Generate fresh link token on every click
        fetch('/api/merge/create-link-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                category: 'hris' // Can be 'hris', 'ats', 'crm', 'accounting', 'ticketing', 'filestorage', 'knowledgebase'
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Reset initialization state for fresh setup
                mergeLinkInitialized = false;
                initializeMergeLink(data.link_token);
            } else {
                alert('Failed to initialize: ' + data.error);
                resetButton();
            }
        });
    });
});
```

### Integration Management

#### Connected Integrations Display
```html
<!-- Show active integrations -->
<div class="card mb-3">
    <div class="card-body">
        <div class="d-flex align-items-center">
            <div class="bg-success rounded-circle me-3">
                <i data-feather="users" class="text-white"></i>
            </div>
            <div>
                <h6 class="mb-1">BambooHR</h6>
                <small class="text-success">Connected</small>
                <small class="text-muted">Automatic sync</small>
            </div>
        </div>
        <div class="btn-group">
            <button onclick="relinkIntegration(123)">Relink</button>
            <button onclick="deleteIntegration(123, 'BambooHR')">Delete</button>
        </div>
    </div>
</div>
```

#### Relinking Implementation
```javascript
function relinkIntegration(integrationId) {
    // Generate fresh token for existing integration
    fetch('/api/merge/relink-integration', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ integration_id: integrationId })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Initialize modal with relink token
            initializeMergeLinkForRelink(data.link_token);
        }
    });
}
```

#### Deletion Implementation
```javascript
function deleteIntegration(integrationId, integrationName) {
    if (confirm('This action is permanent. Do you want to proceed?')) {
        fetch('/api/merge/delete-integration', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ integration_id: integrationId })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                window.location.reload();
            }
        });
    }
}
```

## Key Implementation Patterns

### Fresh Token Generation
- **Always generate new link_token** on every button click
- **Never cache or reuse** tokens between attempts
- **Reset MergeLink state** for clean initialization each time
- **Specify category** in token requests ('hris', 'ats', 'crm', 'accounting', 'ticketing', 'filestorage', 'knowledgebase')

### Callback Management
- **Handle all callbacks**: onSuccess, onExit, onError, onReady
- **Reset button state** in exit/error scenarios
- **Provide user feedback** for error conditions without technical details

### State Management
- **Track initialization state** to prevent conflicts
- **Clean button states** on all completion scenarios
- **Handle page refresh** to show updated integrations

## Testing Checklist

### Initial Connection
- [ ] Button click generates fresh link token
- [ ] Modal opens automatically when ready
- [ ] User can complete authentication flow
- [ ] Integration appears in connected list after success
- [ ] Button resets properly on modal exit/error

### Relinking
- [ ] Relink button opens modal with same integration
- [ ] Completed relink maintains same integration display
- [ ] No duplicate records created in database
- [ ] Same integration name and status preserved

### Deletion
- [ ] Delete button shows confirmation dialog
- [ ] Integration removed from display after confirmation
- [ ] Integration removed from Merge system
- [ ] Database record properly cleaned up

### Error Handling
- [ ] Network errors show user-friendly messages
- [ ] Button state resets on all error conditions
- [ ] Failed integrations don't create incomplete records
- [ ] Console logging for debugging without user exposure

## App Center/Integration Marketplace Implementation

### Single Integration Mode

The key difference between a Connect Button and an App Center is **Single Integration Mode** - directing users to a specific integration rather than showing Merge's full marketplace.

#### Core Concept
When users select an integration from your marketplace (BambooHR, Workday, etc.), they should go directly to that provider's authentication screen, not Merge's integration selection page.

#### Backend Implementation
**Minimal Change Required**: Add optional `integration` parameter to existing link token creation:

```javascript
// Connect Button approach - shows Merge marketplace
{
    category: 'hris'
}

// App Center approach - targets specific integration  
{
    category: 'hris',
    integration: 'bamboohr'  // NEW: Skip marketplace, go directly to BambooHR
}
```

**Backend accepts both patterns** - same endpoint, same logic, just one additional optional parameter.

#### Integration Slug Mapping
Common HRIS integration slugs:
- `bamboohr` → BambooHR
- `workday` → Workday  
- `adp-workforce-now` → ADP Workforce Now
- `hibob` → HiBob
- `officient` → Officient

**Discovery**: Use Merge's `/api/organizations/integrations` endpoint to get available integrations and their slugs.

### Architecture Patterns

#### Multi-Integration State Management
**Challenge**: Managing connect button states across multiple integrations simultaneously.

**Solution Patterns**:
```javascript
// Track current connection attempt
let currentConnectButton = null;

// Button state management
function resetConnectButton(button) {
    if (button) {
        button.disabled = false;
        button.innerHTML = 'Connect';
    }
}

// Handle per-integration loading states
function connectIntegration(category, integration) {
    const button = findButtonForIntegration(integration);
    
    // Show loading state
    button.disabled = true;
    button.innerHTML = 'Connecting...';
    
    // Store for later reset
    currentConnectButton = button;
    
    // Same link token flow as Connect Button
    generateLinkToken(category, integration);
}
```

#### Category Organization
**Implementation Agnostic**: However you organize integrations (tabs, sidebar, dropdown, etc.), the Merge concepts remain:

- **Categories**: HRIS, ATS, CRM, Accounting, Ticketing, FileStorage, Knowledge Base
- **Integration Selection**: User picks specific provider within category
- **Same Token Flow**: Generate → Authenticate → Exchange (unchanged)

### Callback Considerations

**Identical to Connect Button**: All Merge Link callbacks work the same way.

```javascript
// Same onSuccess handler
function onSuccess(public_token) {
    // Exchange token via same backend endpoint
    fetch('/api/merge/exchange-public-token', {
        method: 'POST',
        body: JSON.stringify({ public_token })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Refresh to show connected integration
            window.location.reload();
        }
    });
}

// Reset the current button state on exit/error
function onExit(error) {
    resetConnectButton(currentConnectButton);
}

function onError(error) {
    resetConnectButton(currentConnectButton);
}
```

### Error Handling Patterns

#### Network Failures
**Graceful Degradation**: When integration metadata API fails, provide fallback options:

```javascript
// Primary: Dynamic integration list from Merge API
fetchAvailableIntegrations()
  .then(integrations => renderIntegrations(integrations))
  .catch(error => {
      // Fallback: Static integration list
      renderIntegrations(fallbackIntegrations);
  });
```

#### Button State Recovery
**Critical**: Always reset button states on modal close, error, or success to prevent stuck loading states.

### Integration Discovery

#### Available Integrations API
```javascript
// Fetch integrations user can connect to
fetch('/api/merge/integrations')  // Your backend proxies Merge API
  .then(response => response.json())
  .then(data => {
      const hrisIntegrations = data.integrations.filter(
          integration => integration.categories.includes('hris')
      );
      renderHRISIntegrations(hrisIntegrations);
  });
```

#### Integration Metadata
Each integration includes:
- `name`: Display name (e.g., "BambooHR")
- `slug`: API identifier (e.g., "bamboohr") 
- `categories`: Supported categories (e.g., ["hris"])
- `image`/`square_image`: Logos for UI
- `color`: Brand color for theming

### Testing Approach

#### Single Integration Flow
- [ ] Correct integration slug passed to link token creation
- [ ] Modal opens directly to selected provider (not Merge marketplace)
- [ ] Successful authentication creates correct database record
- [ ] Integration appears in connected state after completion

#### Multi-Integration Management  
- [ ] Multiple connect buttons work independently
- [ ] Button states reset correctly on modal close/error
- [ ] No interference between different integration attempts
- [ ] State management handles concurrent connection attempts gracefully

#### Category Switching
- [ ] Integration filtering works correctly by category
- [ ] Category changes don't break connection flows
- [ ] State resets appropriately when switching categories

## Key Implementation Differences

### From Merge Perspective: Minimal
- **Same authentication flow** (3 steps unchanged)
- **Same database patterns** (End User Origin ID strategy unchanged)
- **Same backend endpoints** (existing endpoints work with one parameter addition)
- **Same error handling** (onSuccess/onExit/onError patterns identical)

### From User Experience Perspective: Significant
- **Discovery-focused**: Users browse and select integrations
- **Category-organized**: Logical grouping of integration types
- **Multi-option management**: Handle many integration states simultaneously
- **Scalable architecture**: Easy to add new categories and integrations

### Implementation Complexity: Frontend Heavy
**Backend Changes**: Minimal (accept `integration` parameter)
**Frontend Changes**: Significant (marketplace UI, state management, category organization)
**Merge Integration**: Identical patterns, just parameter variation