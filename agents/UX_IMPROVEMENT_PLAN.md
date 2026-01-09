# Healarr UX Improvement Plan

**Date:** 2026-01-09
**Version Analyzed:** v1.1.24
**Analysis Method:** User journey mapping with expert system prompt guidance

---

## Executive Summary

Analysis of 5 core user journeys identified **15 improvement opportunities** across usability, error handling, and feature discoverability. Core functionality is solid, but friction points exist in onboarding and troubleshooting.

| Category | Issues Found | Priority |
|----------|-------------|----------|
| Setup & Onboarding | 4 | High |
| Error Handling | 3 | High |
| Configuration UX | 4 | Medium |
| Troubleshooting | 2 | Medium |
| Polish & Accessibility | 2 | Low |

---

## User Journeys Analyzed

### 1. First-Time Setup Journey

**Path:** Install → Setup Wizard → Password → *arr Connection → Path Config → First Scan

**Current Strengths:**
- Clear welcome screen with Fresh Start vs Restore options
- Step indicator shows progress
- *arr connection test before proceeding
- Auto-loads root folders from *arr API
- "What's next?" guidance on completion

**Pain Points Identified:**

| Issue | Impact | Effort |
|-------|--------|--------|
| No FileBrowser in wizard - users must type paths | High | Medium |
| No path mapping validation preview | High | Medium |
| No password strength indicator | Low | Low |
| Skip implications unclear | Medium | Low |

---

### 2. Daily Monitoring Journey

**Path:** Dashboard → Check Status → View Active Scans → Review Corruptions

**Current Strengths:**
- ConfigWarningBanner alerts if setup incomplete
- Status breakdown with 6 states clickable to filtered views
- Real-time active scans table with progress bars
- Activity chart and type distribution for trends

**Pain Points Identified:**

| Issue | Impact | Effort |
|-------|--------|--------|
| No quick "Start Scan" action on dashboard | Medium | Low |
| "Manual Intervention" not explained | High | Low |
| Success rate calculation unclear | Low | Low |

---

### 3. Configuration Management Journey

**Path:** Config Page → Add Instance → Add Path → Set Schedule → Configure Notifications

**Current Strengths:**
- Quick Actions section for common operations
- Server status indicators (Online/Offline)
- Export/Import configuration
- Detection method preview
- Notification test functionality

**Pain Points Identified:**

| Issue | Impact | Effort |
|-------|--------|--------|
| Page overwhelming (5000+ lines) | High | Medium |
| No guided flow for new users | Medium | Medium |
| Server "Offline" gives no guidance | Medium | Low |
| Cron syntax confusing | Medium | Medium |

---

### 4. Remediation Tracking Journey

**Path:** Corruption Detected → Track Status → View Journey → Resolution

**Current Strengths:**
- Rich media info ("Colony S01E08" not just paths)
- *arr icons and download client icons
- Download progress inline
- Multi-select with bulk operations
- RemediationJourney modal with full history

**Pain Points Identified:**

| Issue | Impact | Effort |
|-------|--------|--------|
| No search by media title | Medium | Medium |
| RemediationJourney modal not discoverable | Low | Low |
| "Manual Intervention" action unclear | High | Low |

---

### 5. Troubleshooting Journey

**Path:** Error Encountered → Find Help → Resolve Issue

**Current Strengths:**
- Three-method scan guide (Webhooks, Manual, Scheduled)
- Status table with color legend
- Docker configuration reference
- Accordion sections for organization

**Pain Points Identified:**

| Issue | Impact | Effort |
|-------|--------|--------|
| No troubleshooting section | High | Low |
| No FAQ | Medium | Low |
| No GitHub issues link | Low | Low |
| Accessibility errors not documented | Medium | Low |

---

## Improvement Plan

### Phase 1: Critical Path Fixes (High Priority)

#### 1.1 Setup Wizard - FileBrowser Integration

**Problem:** Users must manually type paths, leading to errors and support requests.

**Solution:**
- Add FileBrowser component to the path step
- Auto-populate local_path from browsed directory
- Show directory contents preview (X files found)

**Files to Modify:**
- `frontend/src/components/SetupWizard.tsx`

**Validation:**
- New user can complete setup without typing paths
- Path selection shows file count confirmation

---

#### 1.2 Help Page - Troubleshooting Section

**Problem:** Users stuck with errors have no in-app guidance.

**Solution:** Add new accordion section covering:

| Question | Answer Summary |
|----------|---------------|
| "Why is my file stuck in Pending?" | Check *arr connection, verify path mapping |
| "Why did remediation fail?" | Max retries, search found nothing, import blocked |
| "Files being skipped?" | Accessibility errors (mount lost, permissions) |
| "Connection refused?" | URL format, firewall, internal Docker DNS |
| "How do I report a bug?" | Link to GitHub issues |

**Files to Modify:**
- `frontend/src/pages/Help.tsx`

**Validation:**
- FAQ covers top 5 support questions

---

#### 1.3 Manual Intervention - Actionable Guidance

**Problem:** Banner says "needs attention" but users don't know what to do.

**Solution:**
```
Current: "These corruptions could not be automatically remediated and need
         attention in Sonarr/Radarr."

Proposed: "These items are blocked in your *arr application.
          Action needed:
          1. Open [Sonarr] (link) and check Activity → Queue
          2. Look for blocked imports or manually removed items
          3. Resolve the issue in *arr, then click Retry here"
```

**Files to Modify:**
- `frontend/src/pages/Corruptions.tsx` (banner text)
- `frontend/src/lib/formatters.ts` (state descriptions)

**Validation:**
- User knows exactly where to look and what to do

---

#### 1.4 Error Message Humanization

**Problem:** Technical error codes confuse users ("ETIMEDOUT", "ECONNREFUSED").

**Solution:** Create error message mapper:

```typescript
// frontend/src/lib/errors.ts (new file)
const errorMap: Record<string, string> = {
  'ETIMEDOUT': 'Connection timed out. Check if the service is running and reachable.',
  'ECONNREFUSED': 'Connection refused. Verify the URL and check firewall settings.',
  'ENOTFOUND': 'Server not found. Check the URL is correct.',
  'certificate': 'SSL certificate error. Try using http:// instead of https://',
  '401': 'Authentication failed. Check your API key.',
  '403': 'Access denied. Verify API key permissions.',
  '404': 'Endpoint not found. Check the URL path.',
  '500': 'Server error. The *arr application encountered a problem.',
};

export function humanizeError(error: string): string {
  for (const [key, message] of Object.entries(errorMap)) {
    if (error.toLowerCase().includes(key.toLowerCase())) {
      return message;
    }
  }
  return error;
}
```

**Files to Modify:**
- `frontend/src/lib/errors.ts` (new)
- `frontend/src/contexts/ToastContext.tsx` (integrate)
- All pages with error handling

**Validation:**
- All error toasts use human-readable messages

---

### Phase 2: Usability Improvements (Medium Priority)

#### 2.1 Path Validation Preview

**Problem:** Users don't know if path mapping is correct until scan fails.

**Backend:**
```go
// GET /api/scan-paths/:id/validate
type PathValidation struct {
    Accessible  bool     `json:"accessible"`
    FileCount   int      `json:"file_count"`
    SampleFiles []string `json:"sample_files"` // First 5 media files
    Error       string   `json:"error,omitempty"`
}
```

**Frontend:**
- Green checkmark: "Found 1,234 media files"
- Red X: "Path not accessible: Permission denied"
- Show sample files as preview

**Files to Modify:**
- `internal/api/handlers_config.go`
- `frontend/src/pages/Config.tsx`

---

#### 2.2 Dashboard Quick Scan

**Problem:** Must navigate to Config page to start a scan.

**Solution:**
- Add dropdown menu next to "System Overview" title
- Lists configured scan paths with play button
- "Scan All" option at bottom

**Files to Modify:**
- `frontend/src/pages/Dashboard.tsx`

---

#### 2.3 Config Page - Collapsible Sections

**Problem:** Page is overwhelming (renders all sections at once).

**Solution:**
- Use accordion pattern (exists in Help page)
- Default expanded: Quick Actions, *arr Instances, Scan Paths
- Default collapsed: Schedules, Notifications, Advanced

**Files to Modify:**
- `frontend/src/pages/Config.tsx`

---

#### 2.4 Schedule - Human-Readable Cron Builder

**Problem:** Users unfamiliar with cron syntax.

**Solution:**
- Preset options: "Daily at midnight", "Weekly on Sunday", "Every 6 hours"
- Simple builder: Day picker + time picker
- Advanced toggle to show raw cron

**Files to Modify:**
- `frontend/src/pages/Config.tsx` (schedule section)

---

### Phase 3: Polish & Accessibility (Low Priority)

#### 3.1 Mobile Responsive Tables

**Problem:** DataGrid breaks on mobile screens.

**Solution:**
- Card view for screens < 768px
- Horizontal scroll with sticky first column for tablet
- Collapsible row details

**Files to Modify:**
- `frontend/src/components/ui/DataGrid.tsx`

---

#### 3.2 Accessibility Error Visibility

**Problem:** Backend skips files for accessibility reasons but users don't see why.

**Solution:**
- New section in ScanDetails: "Skipped Files"
- Shows: path, reason (mount lost, permission denied, timeout)
- Links to Help page for explanation

**Files to Modify:**
- `frontend/src/pages/ScanDetails.tsx`
- `internal/api/handlers_scans.go`

---

## Validation & Testing Plan

### User Journey Testing (Playwright)

| Test | Steps | Expected Result |
|------|-------|-----------------|
| Fresh Setup | Container start → wizard → first scan | Scan completes successfully |
| Path Validation | Add invalid path → check | Error shown before scan |
| Error Handling | Wrong API key → connect | Human-readable error |
| Manual Intervention | Import blocked → check | Actionable guidance shown |
| Mobile | Access on phone | All features usable |

### Functional Verification

- [ ] Webhook scan triggers correctly
- [ ] Manual scan completes
- [ ] Scheduled scan runs on time
- [ ] Notifications fire for events
- [ ] Remediation journey updates real-time
- [ ] Config export/import roundtrips
- [ ] Database backup restores

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Setup completion rate | Unknown | > 90% |
| Time to first scan | Unknown | < 5 minutes |
| Manual intervention support questions | Baseline | -50% |
| Mobile bounce rate | Unknown | Decrease |

---

## Implementation Order

```
Week 1-2: Phase 1 (Critical)
├── 1.1 FileBrowser in wizard
├── 1.2 Troubleshooting section
├── 1.3 Manual intervention guidance
└── 1.4 Error humanization

Week 3-4: Phase 2 (Usability)
├── 2.1 Path validation preview
├── 2.2 Dashboard quick scan
├── 2.3 Collapsible config sections
└── 2.4 Cron builder

Ongoing: Phase 3 (Polish)
├── 3.1 Mobile responsive
└── 3.2 Accessibility errors
```

---

## Appendix: Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `SetupWizard.tsx` | 947 | First-time setup flow |
| `Dashboard.tsx` | 375 | Daily monitoring |
| `Config.tsx` | 5000+ | Configuration management |
| `Corruptions.tsx` | 506 | Remediation tracking |
| `Help.tsx` | 800+ | Documentation & troubleshooting |
| `ConfigWarningBanner.tsx` | 126 | Critical warning display |

---

*This plan was generated through systematic analysis of all user journeys using the Healarr Expert System Prompt.*
