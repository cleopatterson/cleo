# Cleo — Trust Dashboard & BAS Tracking

> **⚠ ARCHIVED — This brief has been implemented. Refer to `CLAUDE.md` for current state.**

## Claude Code Implementation Brief

**Prepared:** March 2026
**Depends on:** `business-planner-brief.md`, `cleo-metrics-redesign-brief.md`
**Platform:** iOS (SwiftUI, iOS 17+)
**Scope:** Evolve the Metrics tab from single-user P&L into a joint trust financial dashboard with BAS/GST tracking, income gap monitoring, and cloud sync between two Cleo instances.

---

## 1. Context & Problem

Tony and his wife run a joint trust. They each operate their own brand and invoice their own clients, but all revenue flows through one trust entity. The current Cleo app is standalone — each instance stores data locally via Core Data with no shared view.

**Financial situation driving this work:**

- Combined gross income: ~$15k/month (Tony) + variable (wife) — call it ~$17k combined
- Combined expenses + mortgage: ~$20k/month
- Monthly income gap: ~$3k–$5k
- Annual tax liability: ~$40k (no PAYG withholding, paid in May)
- GST collected on every invoice inflates the bank balance — that money is owed to the ATO
- Trust is about to start lodging quarterly BAS

**What they need:**

1. Each person keeps their own Cleo instance (own brand, own clients, own invoices, own calendar)
2. A shared financial view showing combined trust performance
3. Quarterly BAS summary ready to hand to accountant
4. Income gap tracker — how close are we to covering $20k/month
5. GST visibility — how much of what's in the account is owed
6. "Safe to spend" balance — what's actually available after GST + tax provision

**Priority order (from user):**

1. Quarterly BAS summary ready to hand to accountant
2. Income gap tracker — how close are we to covering $20k/month
3. See GST collected vs GST owed at any point
4. Real-time "safe to spend" balance (excluding GST + tax provision)

---

## 2. Architecture Overview

### 2.1 Design Principle: Separate Apps, Shared Ledger

Each Cleo instance remains fully independent for day-to-day operations. The shared layer is **read-only aggregation** — each app pushes lightweight financial summary records to a shared CloudKit zone. Both apps can then render the trust-level dashboard from that shared data.

```
Tony's Cleo                          Wife's Cleo
┌─────────────────┐                  ┌─────────────────┐
│ Core Data       │                  │ Core Data       │
│ (invoices,      │                  │ (invoices,      │
│  expenses,      │                  │  expenses,      │
│  clients)       │                  │  clients)       │
└────────┬────────┘                  └────────┬────────┘
         │ push summary                       │ push summary
         ▼                                    ▼
┌─────────────────────────────────────────────────┐
│         Shared CloudKit Zone                     │
│         (TrustFinancialSummary records)           │
│         Container: iCloud.com.wallboard.cleo     │
└─────────────────────┬───────────────────────────┘
                      │ both apps read
                      ▼
┌─────────────────────────────────────────────────┐
│         Trust Dashboard                          │
│         (rendered in each app's Metrics tab)      │
└─────────────────────────────────────────────────┘
```

### 2.2 Why CloudKit (Not Firebase)

- Already configured: `NSPersistentCloudKitContainer` is the existing Core Data stack (see `PersistenceController.swift`)
- iCloud container `iCloud.com.wallboard.cleo` already exists in entitlements
- No additional accounts, SDKs, or server infrastructure
- Sharing via `CKShare` is a native CloudKit feature — one user creates a shared zone, invites the other via Apple ID
- Free tier covers this use case easily (summary records are tiny)

### 2.3 What Syncs vs What Stays Local

| Data | Syncs? | Reason |
|------|--------|--------|
| Invoices (full records) | **No** | Private to each instance. Client names, amounts, line items stay local. |
| Expenses (full records) | **No** | Private to each instance. |
| Clients | **No** | Each brand has its own client list. |
| Calendar events | **No** | Already synced via EventKit/Google Calendar if needed. |
| Roadmap | **No** | Each person's own task list. |
| `TrustFinancialSummary` | **Yes** | Lightweight monthly aggregation — see §3 for schema. |
| `TrustSettings` | **Yes** | Shared configuration — target income, tax rate, BAS quarters. |
| Business Profile | **No** | Each instance has its own brand identity. |

---

## 3. Data Model — New Entities

### 3.1 TrustFinancialSummary (CloudKit shared zone)

One record per contributor per month. Pushed whenever an invoice or expense is created/updated/deleted.

```swift
/// Synced to shared CloudKit zone
/// Key: contributorID + yearMonth (e.g. "tony-2026-03")
struct TrustFinancialSummary {
    let id: UUID
    let contributorID: String          // Stable identifier per Cleo instance (from BusinessProfile.id)
    let contributorName: String        // Display name ("Tony", "Cleo")
    let yearMonth: String              // "2026-03" — the period this summary covers
    
    // Revenue
    let totalInvoiced: Double          // Sum of all invoice totals (inc GST) for the month
    let totalPaid: Double              // Sum of paid invoice totals for the month
    let totalOutstanding: Double       // Sum of sent/overdue invoice totals
    let invoiceCount: Int              // Number of invoices created this month
    
    // GST (Australian tax)
    let gstCollected: Double           // GST component of all invoices (totalInvoiced / 11 at 10%)
    let gstOnExpenses: Double          // GST component of all expenses (claimable)
    
    // Expenses
    let totalExpenses: Double          // Sum of all expenses for the month (inc GST)
    let expensesByCategory: [String: Double]  // Breakdown: {"Software": 200, "Travel": 450, ...}
    
    // Metadata
    let lastUpdated: Date              // When this summary was last recalculated
}
```

**Core Data entity for local cache + CloudKit sync:**

```
TrustFinancialSummary (Core Data, synced to shared CloudKit zone)
├── id: UUID
├── contributorID: String
├── contributorName: String
├── yearMonth: String
├── totalInvoiced: Double
├── totalPaid: Double
├── totalOutstanding: Double
├── invoiceCount: Int32
├── gstCollected: Double
├── gstOnExpenses: Double
├── totalExpenses: Double
├── expensesByCategoryJSON: String     // JSON-encoded dictionary
├── lastUpdated: Date
└── (no relationships — standalone record)
```

**Uniqueness constraint:** `contributorID` + `yearMonth` — upsert on conflict.

### 3.2 TrustSettings (CloudKit shared zone)

Singleton shared record. Either user can edit.

```
TrustSettings (Core Data, synced to shared CloudKit zone)
├── id: UUID
├── trustName: String                  // "Wall Family Trust"
├── trustABN: String                   // The trust's ABN
├── monthlyIncomeTarget: Double        // $20,000 — the goal to cover expenses + mortgage
├── estimatedTaxRate: Double           // 0.30 — marginal rate for tax provision calc
├── basQuarterStartMonth: Int16        // 7 = July (Australian FY starts July)
├── lastUpdated: Date
└── updatedBy: String                  // contributorID of who last changed it
```

### 3.3 Core Data Model Changes

Add both entities to `Cleo.xcdatamodel`. Mark them for CloudKit sync to a **shared zone** (not the default private zone).

**Important:** The existing private Core Data entities (Invoice, Expense, Client, etc.) must NOT sync to CloudKit. Only `TrustFinancialSummary` and `TrustSettings` go to the shared zone. This requires a **second persistent store** with its own `NSPersistentStoreDescription` pointing to the shared CloudKit zone.

```swift
// In PersistenceController.init():
// Store 1: Local-only (existing — invoices, expenses, clients, etc.)
let localStore = NSPersistentStoreDescription(url: localStoreURL)
localStore.cloudKitContainerOptions = nil  // No sync

// Store 2: Shared CloudKit zone (trust summaries + settings only)
let sharedStore = NSPersistentStoreDescription(url: sharedStoreURL)
let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.wallboard.cleo")
options.databaseScope = .shared
sharedStore.cloudKitContainerOptions = options

container.persistentStoreDescriptions = [localStore, sharedStore]
```

---

## 4. CloudKit Sharing Flow

### 4.1 First-Time Setup (One-Time)

One user (Tony) creates the shared zone and invites the other:

1. Tony opens Settings → "Trust Settings" (new section)
2. Fills in trust name, ABN, monthly target ($20,000), estimated tax rate (30%)
3. Taps "Invite Partner" → system share sheet appears
4. Sends invite via Messages/email to wife's Apple ID
5. Wife accepts → her Cleo instance now reads/writes to the same shared zone

**Implementation:** Use `UICloudSharingController` to manage the share. The `TrustSettings` record is the share root — when it's shared, all `TrustFinancialSummary` records in the same zone come along.

### 4.2 Ongoing Sync

Each Cleo instance recalculates and pushes its `TrustFinancialSummary` for the current month whenever:

- An invoice is created, edited, sent, or marked as paid
- An expense is added, edited, or deleted
- App opens (if the cached summary is stale by >1 hour)

**Sync is fire-and-forget.** The summary is a computed projection of local data. If CloudKit is unavailable, the app shows local-only data and retries on next trigger. No user-facing error — the dashboard gracefully degrades to "Your data only" mode with a subtle indicator.

### 4.3 Conflict Resolution

`TrustFinancialSummary` records are **append-only per contributor** — Tony only writes his own records, wife only writes hers. No write conflicts possible.

`TrustSettings` is the only shared-write record. Use last-write-wins (`NSMergeByPropertyObjectTrumpMergePolicy` — already configured). Changes are infrequent (target income, tax rate) so conflicts are practically impossible.

---

## 5. Metrics Tab — Evolved Layout

### 5.1 New Screen Structure

The Metrics tab evolves from the current layout (briefing → P&L → time tracking) to:

```
1. Trust Briefing Card (AI-generated, replaces current monthly briefing)
2. Income Gap Tracker (NEW)
3. BAS / GST Card (NEW)
4. Profit & Loss Card (EXISTING — expanded to show combined trust data)
5. Time Tracking Section (EXISTING — unchanged, personal only)
```

When the shared zone has no partner data (wife hasn't set up yet, or CloudKit unavailable), cards 1–3 show local-only data with a "Solo mode — invite your partner to see combined data" hint.

### 5.2 Trust Briefing Card

Replaces the current monthly briefing. Same visual treatment (teal gradient), but the AI prompt now receives combined trust data.

**Label:** `✦ [Month] [Year]` (e.g. "✦ March 2026")
**Headline:** Combined profit/revenue summary (e.g. "$15,200 invoiced this month")
**Subtext:** AI-generated context covering both contributors, BAS status, gap progress
**Tags:** `Revenue $X` `Expenses $X` `GST owed $X`

**AI Briefing payload (new fields):**

```json
{
  "tab": "metrics",
  "today": "2026-03-29",
  "data": {
    "contributors": [
      {
        "name": "Tony",
        "revenue": 12400,
        "expenses": 3200,
        "gstCollected": 1127,
        "invoiceCount": 4,
        "outstanding": 2200
      },
      {
        "name": "Wife",
        "revenue": 2800,
        "expenses": 900,
        "gstCollected": 254,
        "invoiceCount": 2,
        "outstanding": 0
      }
    ],
    "combined": {
      "totalRevenue": 15200,
      "totalExpenses": 4100,
      "netProfit": 11100,
      "gstCollected": 1381,
      "gstOnExpenses": 372,
      "netGSTPayable": 1009,
      "taxProvision": 3330,
      "safeToSpend": 6691,
      "incomeTarget": 20000,
      "incomeGapPercent": 76
    },
    "bas": {
      "quarter": "Q3 FY26",
      "quarterStart": "2026-01-01",
      "quarterEnd": "2026-03-31",
      "dueDate": "2026-04-28",
      "daysUntilDue": 30,
      "quarterGSTCollected": 3420,
      "quarterGSTOnExpenses": 410,
      "quarterNetGSTPayable": 3010
    }
  }
}
```

### 5.3 Income Gap Tracker Card

**Purpose:** Answer "Are we covering our $20k/month?" at a glance.

**Visual elements:**

- Section label: `INCOME GAP TRACKER` (amber) + `NEW` badge
- Period badge: "This month" (top right)
- Progress bar: Combined revenue as percentage of target
  - Fill: teal gradient (`rgba(62,207,154,0.35)` → `rgba(62,207,154,0.2)`)
  - Track: `rgba(255,255,255,0.04)`
  - Revenue amount label inside the fill (teal)
  - Height: 28px, border-radius: 8px
- Below bar: "Target: $20,000/mo" (left, dim) and "Gap: $X" (right, coral)
- Divider
- Three-column breakdown below:
  - Column 1: "Tony" label + his revenue (teal)
  - Column 2: "Wife" label + her revenue (purple `#b794f6`)
  - Column 3: "Safe to spend" label + calculated amount (amber)

**Safe to spend formula:**

```
safeToSpend = combinedRevenue
            - netGSTPayable           // GST collected minus GST on expenses
            - taxProvision            // netProfit × estimatedTaxRate
            - combinedExpenses
```

**Note:** This is a rough guide, not accounting advice. The card should include a subtle disclaimer: "Estimate only — consult your accountant."

### 5.4 BAS / GST Card

**Purpose:** Quarterly BAS summary ready to hand to accountant, plus a "not your money" warning.

**Visual elements:**

- Section label: `BAS — Q3 FY26` (coral) + `NEW` badge
- Due date badge: "Due 28 Apr" (top right)
- 2×2 grid of metric cells:
  - **GST collected** (teal): Sum of GST on all invoices this quarter. Sub-label: "On $X revenue"
  - **GST paid** (coral): Sum of GST component of expenses this quarter. Sub-label: "On $X expenses"
  - **Net GST payable** (amber): GST collected minus GST paid. Sub-label: "Set aside now"
  - **Tax provision** (amber): Net profit × estimated tax rate for the quarter. Sub-label: "PAYG estimate"
- Warning card below the grid:
  - Amber border + background: `rgba(251,146,60,0.08)` border `rgba(251,146,60,0.15)`
  - Text: "⚠ $X in your account is not yours"
  - Subtitle: "GST owed + tax provision for this quarter"

**Quarter calculation (Australian financial year):**

```swift
/// Australian FY runs July–June
/// Q1: Jul–Sep (BAS due 28 Oct)
/// Q2: Oct–Dec (BAS due 28 Feb)
/// Q3: Jan–Mar (BAS due 28 Apr)
/// Q4: Apr–Jun (BAS due 28 Jul)

func currentBASQuarter(for date: Date = Date()) -> (label: String, start: Date, end: Date, due: Date) {
    let cal = Calendar.current
    let month = cal.component(.month, from: date)
    let year = cal.component(.year, from: date)
    
    switch month {
    case 7...9:   // Q1
        let fy = year + 1
        return ("Q1 FY\(fy % 100)", 
                date(year, 7, 1), date(year, 9, 30), date(year, 10, 28))
    case 10...12: // Q2
        let fy = year + 1
        return ("Q2 FY\(fy % 100)", 
                date(year, 10, 1), date(year, 12, 31), date(year + 1, 2, 28))
    case 1...3:   // Q3
        let fy = year
        return ("Q3 FY\(fy % 100)", 
                date(year, 1, 1), date(year, 3, 31), date(year, 4, 28))
    case 4...6:   // Q4
        let fy = year
        return ("Q4 FY\(fy % 100)", 
                date(year, 4, 1), date(year, 6, 30), date(year, 7, 28))
    default: fatalError()
    }
}
```

**GST calculation notes:**

- Australian GST is 10%. GST-inclusive invoices: GST component = total ÷ 11
- All Cleo invoices already have `taxRate: 0.10` and calculate `taxAmount = subtotal × taxRate`
- For expenses: assume all logged expenses include GST unless categorised as GST-free. For v1, assume all expenses include GST (GST component = amount ÷ 11). A future version can add a "GST-free" toggle per expense.
- BAS field mapping: 1A = GST collected on sales, 1B = GST paid on purchases, net = 1A − 1B

### 5.5 Existing Cards — Modifications

**Profit & Loss Card:**
- Add a header subtitle: "Combined trust — last 30 days" (when partner data available) or "Your business — last 30 days" (solo mode)
- Revenue and expense bars now show combined totals
- No other visual changes

**Time Tracking Section:**
- Unchanged. This is personal data only — not shared via the trust.

---

## 6. Business Profile — New Settings Section

### 6.1 Trust Settings (New Section in BusinessProfileView)

Add a new section below "Invoice Defaults":

```
Section("Trust") {
    TextField("Trust Name", text: $trustName)
    TextField("Trust ABN", text: $trustABN)
        .keyboardType(.numberPad)
    
    HStack {
        Text("Monthly Income Target")
        Spacer()
        TextField("20000", text: $incomeTarget)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
    }
    
    HStack {
        Text("Est. Tax Rate")
        Spacer()
        TextField("30", text: $taxRate)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 60)
        Text("%")
            .foregroundStyle(.secondary)
    }
    
    // Partner sharing
    if hasSharedZone {
        HStack {
            Label("Partner connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Spacer()
            Text(partnerName)
                .foregroundStyle(.secondary)
        }
    } else {
        Button("Invite Partner") {
            showShareSheet = true
        }
    }
}
```

---

## 7. New Service: TrustSyncService

### 7.1 Responsibilities

```swift
/// Manages the shared CloudKit zone and trust-level data aggregation
@Observable
class TrustSyncService {
    // State
    var isConnected: Bool = false          // Has partner accepted share?
    var partnerName: String?               // Partner's contributorName
    var lastSyncDate: Date?
    
    // Aggregated data (computed from local + shared summaries)
    var currentMonthSummaries: [TrustFinancialSummary] = []
    var currentQuarterSummaries: [TrustFinancialSummary] = []
    var trustSettings: TrustSettings?
    
    // MARK: - Push (called by InvoicingViewModel on any invoice/expense change)
    
    /// Recalculates and pushes the current user's monthly summary
    func pushSummary(
        invoices: [Invoice],
        expenses: [Expense],
        profile: BusinessProfile
    ) async
    
    // MARK: - Read (called by MetricsViewModel)
    
    /// Returns combined data for the current month from all contributors
    func combinedMonthlyData() -> TrustMonthlyAggregate
    
    /// Returns combined data for the current BAS quarter
    func currentQuarterBAS() -> BASQuarterSummary
    
    // MARK: - Sharing
    
    /// Creates the shared zone and returns a UICloudSharingController
    func createShare() async throws -> UICloudSharingController
    
    /// Accepts an incoming share
    func acceptShare(_ metadata: CKShare.Metadata) async throws
}
```

### 7.2 Computed Aggregates

```swift
struct TrustMonthlyAggregate {
    let contributors: [ContributorSummary]
    let combinedRevenue: Double
    let combinedExpenses: Double
    let netProfit: Double
    let gstCollected: Double
    let gstOnExpenses: Double
    let netGSTPayable: Double
    let taxProvision: Double       // netProfit × estimatedTaxRate
    let safeToSpend: Double
    let incomeTarget: Double
    let gapAmount: Double          // max(0, incomeTarget - combinedRevenue)
    let gapPercent: Double         // combinedRevenue / incomeTarget × 100
    let isSoloMode: Bool           // true if no partner data
}

struct ContributorSummary {
    let name: String
    let revenue: Double
    let expenses: Double
    let gstCollected: Double
}

struct BASQuarterSummary {
    let quarterLabel: String       // "Q3 FY26"
    let quarterStart: Date
    let quarterEnd: Date
    let dueDate: Date
    let daysUntilDue: Int
    let gstCollected: Double       // Field 1A
    let gstOnExpenses: Double      // Field 1B
    let netGSTPayable: Double      // 1A - 1B
    let totalRevenue: Double       // Ex-GST revenue for the quarter
    let totalExpenses: Double      // Ex-GST expenses for the quarter
    let taxProvision: Double       // Net profit × estimated tax rate
    let notYourMoney: Double       // netGSTPayable + taxProvision
}
```

---

## 8. Integration Points

### 8.1 InvoicingViewModel Changes

After any invoice or expense mutation (create, edit, delete, status change), call:

```swift
// At the end of createInvoice(), markAsPaid(), deleteInvoice(), 
// addExpense(), deleteExpense(), etc.:
Task {
    await trustSyncService.pushSummary(
        invoices: invoices,
        expenses: expenses,
        profile: persistence.getOrCreateBusinessProfile()
    )
}
```

### 8.2 MetricsViewModel Changes

The `MetricsViewModel` already has `monthlyRevenue`, `monthlyExpenses`, `netProfit`, etc. These need to be extended:

```swift
// New properties
var trustAggregate: TrustMonthlyAggregate?
var basQuarter: BASQuarterSummary?
var isSoloMode: Bool { trustAggregate?.isSoloMode ?? true }

// In loadData():
func loadData() async {
    await timeService.loadIfNeeded()
    refreshFinancials()
    
    // NEW: Load trust data
    trustAggregate = trustSyncService.combinedMonthlyData()
    basQuarter = trustSyncService.currentQuarterBAS()
}
```

### 8.3 AI Briefing Prompt Update

The Metrics tab briefing prompt needs to be updated to include trust-level data. See the payload structure in §5.2. The system prompt should instruct Claude to:

- Reference both contributors by name
- Highlight the income gap and whether it's closing or widening
- Flag BAS due dates when within 30 days
- Warn about GST + tax provision amounts
- Keep the same warm, direct, business-savvy voice

### 8.4 App Entry Point

`CleoApp.swift` needs to:

1. Instantiate `TrustSyncService` alongside existing services
2. Pass it to `ContentView` and down to `MetricsTabView`
3. Handle incoming `CKShare.Metadata` via `onOpenURL` or `userDidAcceptCloudKitShareWith`

---

## 9. Design Tokens (New)

Reuses the existing Cleo design system. New tokens for the trust cards:

```
// Income Gap Tracker
Gap bar fill:       linear-gradient(90deg, rgba(62,207,154,0.35), rgba(62,207,154,0.2))
Gap bar track:      rgba(255,255,255,0.04)
Gap bar height:     28px
Gap bar radius:     8px
Tony accent:        #3ecf9a (teal — same as existing revenue)
Wife accent:        #b794f6 (purple — matches her app's likely brand)

// BAS Card
Quarter grid gap:   8px
Quarter cell bg:    rgba(255,255,255,0.03)
Quarter cell border: rgba(255,255,255,0.04)
Quarter cell radius: 10px
Warning bg:         rgba(251,146,60,0.08)
Warning border:     rgba(251,146,60,0.15)
Warning text:       #fb923c (amber)

// Shared
New badge bg:       rgba(251,146,60,0.2)
New badge text:     #fb923c
New badge size:     8px uppercase
```

---

## 10. Build Order

### Phase 1 — Core Data + CloudKit Plumbing (Week 1)

1. Add `TrustFinancialSummary` and `TrustSettings` entities to `Cleo.xcdatamodel`
2. Configure second persistent store for shared CloudKit zone in `PersistenceController`
3. Create `TrustSyncService` with push/read methods
4. Wire push calls into `InvoicingViewModel` mutation methods
5. Test: Verify records appear in CloudKit Dashboard

### Phase 2 — Trust Settings UI (Week 1-2)

1. Add "Trust" section to `BusinessProfileView`
2. Implement `UICloudSharingController` integration for partner invite
3. Handle incoming share acceptance in `CleoApp.swift`
4. Test: Two devices can see each other's summary records

### Phase 3 — BAS / GST Card (Week 2-3)

1. Implement `currentBASQuarter()` helper with Australian FY logic
2. Implement `BASQuarterSummary` computation in `TrustSyncService`
3. Build `BASQuarterCard` SwiftUI view (2×2 grid + warning)
4. Wire into `MetricsTabView` below the briefing card
5. Test: Verify GST calculations match manual spreadsheet

### Phase 4 — Income Gap Tracker (Week 3)

1. Build `IncomeGapCard` SwiftUI view (progress bar + breakdown)
2. Wire `TrustMonthlyAggregate` data into the card
3. Implement "safe to spend" formula
4. Add "Solo mode" fallback for when no partner data exists
5. Test: Verify gap calculations with known inputs

### Phase 5 — Briefing Evolution (Week 4)

1. Update AI briefing payload to include trust-level data (§5.2)
2. Update system prompt for trust-aware commentary
3. Update `MetricsViewModel.fallbackHeadline` / `fallbackSummary` for trust context
4. Modify existing P&L card to show "Combined trust" header when partner data available

### Phase 6 — Wife's Onboarding (Week 4)

1. Wife installs Cleo, completes business profile setup (her brand)
2. Tony sends CloudKit share invite
3. Wife accepts → shared zone active
4. Both apps now show combined trust dashboard
5. Verify: Changes in one app appear in the other within ~30 seconds

---

## 11. Edge Cases & Graceful Degradation

| Scenario | Behaviour |
|----------|-----------|
| No partner connected | Show local-only data. "Solo mode" hint on trust cards. All calculations use single contributor. |
| CloudKit unavailable (offline) | Show last-cached data. Subtle "Last synced: X ago" indicator. Push queues and retries when online. |
| Partner hasn't logged any data yet | Show their contribution as $0. Don't hide the card. |
| Mid-quarter join | BAS card shows data from the join date forward. Prior months show "No data" for partner. |
| One partner deletes app | Their summary records remain in CloudKit. Dashboard continues showing last-known data with a "Not updated since X" note. |
| Tax rate or target changes | `TrustSettings` updates propagate via CloudKit. Both apps pick up new values on next sync. |

---

## 12. Out of Scope (Future)

- **BAS PDF export** — Generate a formatted BAS summary PDF to email to accountant. Logical next step after v1.
- **Historical quarter comparison** — "Q3 vs Q2" trend cards.
- **Expense categorisation for BAS** — GST-free vs GST-inclusive toggle per expense.
- **PAYG instalment tracking** — Actual vs estimated tax payments.
- **Bank feed integration** — Auto-reconcile invoices with bank transactions.
- **Multi-trust support** — Only one trust per Cleo instance for now.
- **Accountant view/export** — Structured data export (CSV/Xero format) for accountant.

---

## 13. Key Files to Modify

| File | Change |
|------|--------|
| `Cleo.xcdatamodel` | Add `TrustFinancialSummary` + `TrustSettings` entities |
| `PersistenceController.swift` | Add second store for shared CloudKit zone |
| `CleoApp.swift` | Instantiate `TrustSyncService`, handle share acceptance |
| `ContentView.swift` | Pass `TrustSyncService` to `MetricsTabView` |
| `MetricsTabView.swift` | Add Income Gap and BAS cards above existing P&L |
| `MetricsViewModel.swift` | Add trust aggregate + BAS quarter properties |
| `InvoicingViewModel.swift` | Call `trustSyncService.pushSummary()` on mutations |
| `BusinessProfileView.swift` | Add "Trust" settings section |
| `ClaudeAPIService.swift` | Update Metrics briefing prompt with trust payload |
| `Cleo.entitlements` | Verify CloudKit shared database entitlement |
| `project.yml` | No changes expected — CloudKit already configured |

### New Files to Create

| File | Purpose |
|------|---------|
| `Cleo/Services/TrustSyncService.swift` | CloudKit shared zone management + aggregation |
| `Cleo/Models/TrustFinancialSummary.swift` | Core Data managed object |
| `Cleo/Models/TrustSettings.swift` | Core Data managed object |
| `Cleo/Views/Metrics/IncomeGapCard.swift` | Income gap tracker view |
| `Cleo/Views/Metrics/BASQuarterCard.swift` | BAS/GST quarterly view |
| `Cleo/Views/Metrics/TrustBriefingCard.swift` | Evolved briefing card (or modify existing) |
| `Cleo/Helpers/BASQuarterHelper.swift` | Australian FY quarter calculations |

---

## 14. Assumptions & Decisions

| Question | Decision |
|----------|----------|
| Trust structure | Single joint trust, both partners invoice through it |
| GST rate | 10% (standard Australian GST) — already the default `taxRate` in Cleo |
| Tax provision rate | Configurable, default 30% — stored in `TrustSettings` |
| Income target | Configurable, default $20,000/month — stored in `TrustSettings` |
| BAS frequency | Quarterly (standard for trusts under $20M revenue) |
| Financial year | Australian: July–June |
| Expense GST | v1 assumes all expenses include GST. Future: per-expense toggle. |
| Sync granularity | Monthly summaries, not individual transactions |
| Share mechanism | CloudKit `CKShare` via `UICloudSharingController` |
| Conflict resolution | Last-write-wins on `TrustSettings`. No conflicts on summaries (per-contributor writes). |

---

*This brief extends the original `business-planner-brief.md`. It should be read alongside that document and `cleo-metrics-redesign-brief.md` for full context on the existing Metrics tab design.*
