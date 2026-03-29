# Cleo — Business Planner for Solopreneurs

## Claude Code Implementation Brief

**Prepared:** March 2026
**Platform:** iOS (SwiftUI, iOS 17+)
**AI Engine:** Claude Haiku 4.5

---

## 1. Overview

Biz is a business planning app built on the same design system and architectural patterns as the existing Family Planner app. It targets solopreneurs and small business owners (specifically husband-and-wife operations) who are currently duct-taping together Google Calendar, Canva invoices, spreadsheets, and sticky notes.

The app has **four tabs**: Calendar, Invoicing, Roadmap, and Metrics. The first three are fully functional at launch; the Metrics tab ships as a "Coming Soon" placeholder. Each tab follows the established three-layer visual hierarchy (AI Briefing → Hero Card → Week Strip / Content), uses the same dark theme, and integrates Claude Haiku for intelligent briefings.

Each user has their own independent app instance — there is no shared/multi-user mode. Tony and Cleo each install their own copy with their own business profile and data.

This is a **new Xcode project** that shares the design system but is a distinct app. There are no current monetisation plans.

---

## 2. Design System (Carry Forward)

### 2.1 Foundation

| Token | Value |
|-------|-------|
| Background | `#0F0A1F` |
| Card surface | `#1A1230` |
| Elevated surface | `#1e1238` |
| Primary text | `#f0e6ff` |
| Mid text | `rgba(240, 230, 255, 0.72)` |
| Dim text | `rgba(240, 230, 255, 0.42)` |
| Border | `rgba(255, 255, 255, 0.06)` |
| Corner radius (large) | `16px` |
| Corner radius (small) | `10px` |
| Font | DM Sans (all weights 300–700) |

### 2.2 Tab Accent Colours

| Tab | Accent | Soft variant |
|-----|--------|-------------|
| Calendar | Purple `#b794f6` | `rgba(139, 92, 246, 0.15)` |
| Invoicing | Green `#00b894` | `rgba(0, 184, 148, 0.12)` |
| Roadmap | Amber `#fb923c` | `rgba(251, 146, 60, 0.15)` |
| Metrics | Blue `#74b9ff` | `rgba(116, 185, 255, 0.12)` |

### 2.3 Three-Layer Visual Hierarchy (Per Tab)

This is the core pattern. Every tab follows the same structure:

1. **AI Briefing card** — The loudest element. Gets the coloured gradient background (e.g., `linear-gradient(145deg, deep-accent 0%, mid-tone 35%, bg-surface 70%, bg-card 100%)`). Contains the `✦ AI BRIEFING` badge, a headline, a 3–4 sentence summary, and 3 stat pills at the bottom.

2. **Hero card** — Quieter. Dark surface card with an emoji in a coloured box (right-aligned), title and subtitle (left-aligned), a thin divider, and a row of metadata pills below.

3. **Content area** — Tab-specific. Could be a horizontal week strip (scrollable day cards at 120px wide), a list, or a dashboard grid. This is where the tab's main interactive content lives.

### 2.4 Shared UI Components to Port

These exist in the Family Planner codebase and should be extracted or rebuilt:

- **AI Briefing Card**: Gradient background, sparkle badge, headline, body, stat pills
- **Hero Card**: Surface card with emoji box, title/subtitle, divider, pill row
- **Horizontal Week Strip**: Scrollable day cards (120px wide), day label, emoji, title, subtitle. Past days faded, today accent-bordered, future days normal.
- **Collapsible Category Sections**: Tap to expand/collapse content groups
- **Pill components**: Coloured tag pills for metadata (effort ramp, categories, statuses)
- **Tab Bar**: 4-tab bar with emoji icons and accent highlight on active tab
- **Shimmer loading state**: For AI briefing regeneration

---

## 3. Tab 1 — Calendar

### 3.1 Purpose

Business-focused calendar for tracking meetings, deadlines, and events. Must integrate with Google Calendar so users don't need to re-enter everything.

### 3.2 Key Design Decision: Sync vs. Rebuild

**Recommended approach: Sync with Google Calendar via EventKit.**

iOS already bridges Google Calendar through the system calendar framework. If the user has added their Google account in iOS Settings, EventKit gives read/write access to those events without any Google API integration. This is the same approach the Family Planner uses.

**What this means:**
- Events created in Hustle appear in Google Calendar and vice versa
- No OAuth flow or Google API keys needed
- Users choose which calendar(s) to display in the app
- The app can create events on any of the user's synced calendars
- Shared calendars (e.g., a business calendar shared with your wife) work automatically

**What this doesn't cover:**
- Google Calendar's "invite via email" feature (EventKit supports adding attendees, but the invite goes through iOS, not Gmail)
- Google Meet link auto-generation

**Open question for Tony:** Do you need to send calendar invites to clients from within the app? If yes, we could compose a `.ics` file and attach it to an email via `MFMailComposeViewController` or a share sheet. This avoids the Google API entirely while still giving recipients a tappable calendar invite.

### 3.3 Three-Layer Layout

**AI Briefing** (purple gradient):
- Headline: "3 meetings today, proposal due Friday"
- Summary: Conversational paragraph about the business week — what's booked, what's coming, any gaps for deep work
- Stat pills: `[Meetings: 5]` `[Deadlines: 2]` `[Free blocks: 3]`

**Hero Card**:
- Shows the next upcoming event (or "next meeting")
- Emoji in purple box (📅, 🤝, 📞 based on event type)
- Title: event name, Subtitle: time + location
- Pills: `[In 2h]` `[Google Meet]` `[Client: Acme]`

**Content Area**:
- Horizontal week strip showing each day with event count dot indicators
- Below: Today's agenda as a vertical list with coloured category borders (meetings = purple, deadlines = red, admin = grey)
- Tap any day in the strip to jump to that day's agenda
- Past events greyed out (same treatment as Family Planner)

### 3.4 Event Creation

- Tap `+` button → event creation sheet
- Fields: title, date/time, calendar (picker from synced calendars), location, notes, attendees
- "Create invite" toggle → generates `.ics` and opens share sheet (email, Messages, AirDrop)
- Events saved via EventKit → automatically sync to Google Calendar

### 3.5 Data Model

```
BusinessEvent (via EventKit / EKEvent)
├── title: String
├── startDate: Date
├── endDate: Date
├── calendar: EKCalendar (user picks which synced calendar)
├── location: String?
├── notes: String?
├── attendees: [EKParticipant]?
└── url: URL? (for meeting links)
```

No custom Core Data entity needed for basic events — EventKit is the source of truth. Custom metadata (like client tags) could be stored in the event's `notes` field as a structured suffix, or in a lightweight Core Data overlay keyed by `eventIdentifier`.

---

## 4. Tab 2 — Invoicing

### 4.1 Purpose

This is the pain-point tab. Replace the "open Canva, duplicate last invoice, manually edit" workflow with a proper create → send → track pipeline. This should feel like a focused tool, not a full accounting suite.

### 4.2 Three-Layer Layout

**AI Briefing** (green gradient):
- Headline: "2 invoices due, $4,200 outstanding"
- Summary: "You sent 3 invoices in February totalling $12,600. Two are still unpaid — the Acme project ($2,800) is 5 days overdue. This month's expenses are tracking at $1,430."
- Stat pills: `[Revenue: $8,400]` `[Outstanding: $4,200]` `[Expenses: $1,430]`

**Hero Card**:
- Shows the most urgent invoice (overdue first, then next due)
- Emoji: 💰 (paid), ⏰ (due soon), 🔴 (overdue)
- Title: "Acme Corp — Website Redesign"
- Subtitle: "$2,800 · Due 3 Mar · 5 days overdue"
- Pills: `[Overdue]` (red), `[Sent 15 Feb]`, `[Net 14]`

**Content Area**:
- **Monthly summary bar**: horizontal bar chart or simple row showing income vs expenses for the current month
- **Invoice list**: sorted by status (overdue → due soon → sent → draft → paid)
- Each invoice row: client name, amount, status pill, due date, sent date
- Tap to view/edit the full invoice

### 4.3 Invoice Creation Flow

This is the core feature. The flow should feel quick and opinionated:

**Step 1 — Client & basics** (sheet/modal):
- Client name (autocomplete from previous invoices)
- Client email
- Invoice number (auto-generated, single global sequence: `INV-2026-0001`, incrementing. Never per-client — sequential with no gaps is the ATO-friendly standard. Year prefix resets visually each financial year without restarting the actual sequence.)
- Invoice date (default: today)
- Due date (default: today + payment terms)
- Payment terms picker: `[Net 7]` `[Net 14]` `[Net 30]` `[Net 60]` `[Custom]`

**Step 2 — Line items**:
- Description, quantity, unit price, line total (auto-calculated)
- "Add line item" button
- Subtotal, tax rate (configurable, default 10% GST for Australia), total
- Notes/terms field at bottom (e.g., "Payment via bank transfer to BSB: xxx Account: xxx")

**Step 3 — Preview & send**:
- PDF preview of the invoice (generated from the data, not a Canva template)
- "Send via Email" → opens `MFMailComposeViewController` with PDF attached, pre-filled recipient, subject line "Invoice INV-2026-001 from [Business Name]"
- "Share" → share sheet (save PDF, AirDrop, Messages, etc.)
- "Save as Draft" → saves without sending

### 4.4 Invoice PDF Generation

Generate a clean, professional PDF programmatically. No templates, no Canva.

**Layout:**
- Header: Business name, ABN, address, logo (optional, stored in app settings)
- Right-aligned: Invoice number, date, due date
- "Bill To" block: Client name, email, address
- Line items table: Description | Qty | Unit Price | Amount
- Footer: Subtotal, GST, Total (bold, large)
- Payment details section: Bank name, BSB, Account number, PayID (from app settings)
- Terms/notes

**Implementation:** Use `UIGraphicsPDFRenderer` or a lightweight HTML-to-PDF approach (render a styled HTML template in a `WKWebView`, export to PDF). The HTML approach is easier to style and iterate on.

### 4.5 Expense Tracking

Lightweight expense entry — not a full bookkeeping tool.

- Quick-add: amount, category, date, note
- Categories: `[Software]` `[Equipment]` `[Travel]` `[Advertising]` `[Subscriptions]` `[Materials]` `[Other]`
- Monthly summary: total expenses, breakdown by category
- Optional: photo of receipt (stored locally via `PhotosUI`)

### 4.6 Data Model

```
Invoice (Core Data)
├── id: UUID
├── invoiceNumber: String ("INV-2026-0001", single global sequence, no gaps)
├── clientName: String
├── clientEmail: String
├── clientAddress: String?
├── issueDate: Date
├── dueDate: Date
├── paymentTerms: Int (days: 7, 14, 30, 60)
├── status: InvoiceStatus (draft, sent, viewed, paid, overdue)
├── sentDate: Date?
├── paidDate: Date?
├── notes: String?
├── taxRate: Double (default 0.10 for GST)
├── lineItems: [InvoiceLineItem]
└── pdfData: Data? (cached generated PDF)

InvoiceLineItem (Core Data)
├── id: UUID
├── description: String
├── quantity: Double
├── unitPrice: Double
└── sortOrder: Int

Expense (Core Data)
├── id: UUID
├── amount: Double
├── category: ExpenseCategory
├── date: Date
├── note: String?
├── receiptImagePath: String?
└── isRecurring: Bool

Client (Core Data) — optional, can be derived from invoices
├── id: UUID
├── name: String
├── email: String
├── address: String?
└── defaultPaymentTerms: Int?

BusinessProfile (Core Data, singleton)
├── businessName: String
├── abn: String?
├── address: String?
├── email: String?
├── phone: String?
├── bankName: String?
├── bsb: String?
├── accountNumber: String?
├── payID: String?
├── logoImagePath: String?
└── defaultTaxRate: Double
```

### 4.7 Invoice Status Tracking

Invoices move through a lifecycle:

```
Draft → Sent → Paid
              → Overdue (automatic: dueDate < today && status == .sent)
```

- **Draft**: created but not sent. Editable.
- **Sent**: email was sent or PDF was shared. `sentDate` recorded. Still editable (with a warning).
- **Overdue**: computed state — any sent invoice past its due date.
- **Paid**: manually marked by the user. `paidDate` recorded.

There's no "viewed" tracking (that would require a hosted invoice link, which is out of scope for v1). The user manually marks invoices as paid.

---

## 5. Tab 3 — Roadmap

### 5.1 Purpose

A strategic planning view. Not a to-do list — a roadmap of what you're building and where the business is heading. Think Notion's timeline view or a simplified Linear roadmap, but for one person (or two).

Cleo's use case: "What am I working toward? What's the next big thing? What tasks need to happen to get there?"

### 5.2 Three-Layer Layout

**AI Briefing** (amber gradient):
- Headline: "2 milestones this month, 5 tasks in progress"
- Summary: "Your 'Launch new pricing page' milestone is due in 8 days with 3 of 5 tasks complete. The 'Q2 content calendar' is still in planning. Consider prioritising the pricing page copywriting task — it's blocking the launch."
- Stat pills: `[In Progress: 5]` `[This Month: 2]` `[Blocked: 1]`

**Hero Card**:
- Shows the next upcoming milestone
- Emoji: 🚀 (launch), 📋 (planning), 🎯 (goal)
- Title: "Launch new pricing page"
- Subtitle: "Due 17 Mar · 3/5 tasks done"
- Pills: `[60%]` (progress), `[8 days left]`, `[2 blocked]`

**Content Area**:
- **View toggle**: `[Timeline]` `[Board]` — two ways to see the same data
- **Timeline view** (default): Vertical list of milestones ordered by target date. Each milestone expands to show its child tasks. Past milestones are faded with a ✓. Current milestones are accent-highlighted.
- **Board view**: Kanban-style columns: `[Backlog]` `[In Progress]` `[Done]`. Horizontally scrollable. Cards are tasks, grouped under their parent milestone.

### 5.3 Data Model

```
Milestone (Core Data)
├── id: UUID
├── title: String
├── emoji: String
├── targetDate: Date?
├── status: MilestoneStatus (planning, inProgress, completed, deferred)
├── notes: String?
├── sortOrder: Int
└── tasks: [RoadmapTask]

RoadmapTask (Core Data)
├── id: UUID
├── title: String
├── status: TaskStatus (backlog, inProgress, done)
├── priority: TaskPriority (low, medium, high, urgent)
├── dueDate: Date?
├── assignee: String? ("Tony", "Cleo")
├── notes: String?
├── isBlocked: Bool
├── blockedReason: String?
├── milestone: Milestone
└── sortOrder: Int
```

### 5.4 Interactions

- Tap milestone to expand/collapse its tasks
- Long-press task to drag between statuses (on board view) or reorder (on timeline view)
- Swipe task left → mark done, swipe right → mark blocked
- Tap `+` on a milestone → add task to that milestone
- Tap `+` in header → create new milestone

### 5.5 The AI Angle

The AI briefing here is genuinely useful — it can look at due dates, completion rates, and blocked items to surface what actually needs attention. The prompt should focus on:
- Which milestones are at risk (tasks incomplete, deadline approaching)
- Which tasks are blocking others
- Suggesting what to focus on today based on priority and deadlines
- Acknowledging completed milestones (positive reinforcement)

---

## 6. Tab 4 — Metrics

### 6.1 Status: Coming Soon (v2)

The Metrics tab ships as a "Coming Soon" placeholder in v1. The tab should exist in the tab bar (📊 icon, blue accent) but display a single centered card with the blue gradient treatment, a 📊 emoji, "Metrics — Coming Soon" headline, and a short description: "Track revenue, growth, and the numbers that matter to your business. Coming in a future update."

### 6.2 Design Notes for Future Implementation

The full spec is preserved here for when we build it. The vision is a customisable widget dashboard:

- **Built-in widgets** auto-populated from invoicing data (revenue, outstanding, expenses, profit)
- **Manual-entry widgets** for metrics the app can't calculate (custom numbers, social followers, weekly ratings)
- **Future API widgets** (Stripe, Google Analytics, Instagram, Shopify) for v3+
- The AI Briefing for this tab would synthesise across all tabs — pulling invoicing, roadmap, and calendar data into a single "how's the business going" summary

No data model or implementation needed for v1 — just the placeholder screen.

---

## 7. AI Briefing System (Carry Forward + Adapt)

### 7.1 Architecture

Identical to the Family Planner. Each tab has its own briefing prompt and refresh cadence.

```
AIBriefingManager
├── generateBriefing(for tab: Tab, with data: TabData) async -> Briefing
├── cachedBriefing(for tab: Tab) -> Briefing?
├── shouldRegenerate(for tab: Tab) -> Bool
└── callCounter: [Tab: DailyCallCount]
```

### 7.2 Refresh Cadence

| Tab | Trigger | Expected Frequency |
|-----|---------|-------------------|
| Calendar | Day changes (midnight), event added/edited | 1–2 calls/day |
| Invoicing | Invoice created/sent/paid, expense added | 1–3 calls/week |
| Roadmap | Task status changed, milestone updated | 1–3 calls/week |
| Metrics | *Deferred to v2 — no API calls in v1* | — |

### 7.3 Cost Controls (Carry Forward)

All the same guardrails from the Family Planner:
- 10-second debounce on all regeneration triggers
- Hard cap: 3 API calls per tab per day
- Cache-first: check local cache + data hash before calling
- Anthropic prompt caching on system prompts (1-hour TTL)
- No background refresh — only on app/tab open
- Core Data logs for analytics (timestamp, tab, token counts, cache hit)

### 7.4 Prompt Design

Each tab sends a structured JSON payload and expects a JSON response:

**Request:**
```json
{
  "tab": "invoicing",
  "today": "2026-03-09",
  "data": {
    "unpaidInvoices": [...],
    "recentExpenses": [...],
    "monthlyRevenue": 6200,
    "lastMonthRevenue": 5530
  }
}
```

**Response:**
```json
{
  "headline": "2 invoices due, $4,200 outstanding",
  "summary": "You sent 3 invoices in February...",
  "stats": [
    { "label": "Revenue", "value": "$8,400" },
    { "label": "Outstanding", "value": "$4,200" },
    { "label": "Expenses", "value": "$1,430" }
  ]
}
```

System prompt should instruct Claude to write in a warm, direct, business-savvy voice. No corporate jargon. No motivational filler. Reference actual client names, amounts, and dates. Flag risks and opportunities.

---

## 8. App Settings / Business Profile

A settings screen (accessible from a profile icon or gear icon) where the user configures:

**Business Details** (used in invoice generation):
- Business name
- ABN
- Address
- Email, phone
- Logo (optional image)

**Payment Details** (printed on invoices):
- Bank name
- BSB
- Account number
- PayID

**Invoice Defaults:**
- Default payment terms (Net 14, Net 30, etc.)
- Default tax rate (10% GST)
- Invoice number prefix ("INV")
- Next invoice number (auto-incrementing, format `INV-YYYY-NNNN`)

**App Settings:**
- Which calendars to sync (EventKit calendar picker)
- AI briefing on/off per tab
- Notification preferences (invoice reminders, deadline alerts)

---

## 9. Data Architecture

### 9.1 Storage

| Data | Storage | Reason |
|------|---------|--------|
| Calendar events | EventKit | Syncs with Google Calendar, no duplication |
| Invoices, expenses, clients | Core Data | Custom data, needs full control |
| Roadmap milestones & tasks | Core Data | Custom data |
| Metric widgets & entries | Core Data | Custom data |
| Business profile | Core Data (singleton) | Lightweight, rarely changes |
| AI briefing cache | Core Data | Timestamp + data hash + response |
| API call logs | Core Data | Analytics |

### 9.2 CloudKit Sync (Optional, Future)

Same pattern as Family Planner: Core Data + CloudKit container for syncing between devices. Not required for v1 but the Core Data model should use `NSPersistentCloudKitContainer` from the start so it's ready.

---

## 10. Navigation & Tab Bar

Four tabs with emoji icons, matching the Family Planner tab bar component:

| Tab | Icon | Accent when active |
|-----|------|-------------------|
| Calendar | 📅 | Purple `#b794f6` |
| Invoicing | 💰 | Green `#00b894` |
| Roadmap | 🗺️ | Amber `#fb923c` |
| Metrics | 📊 | Blue `#74b9ff` |

Tab bar: dark surface (`#1A1230`), inactive tabs at 0.42 opacity, active tab full opacity with accent colour on the icon and label.

---

## 11. Build Order (Suggested)

### Phase 1 — Foundation
1. New Xcode project, SwiftUI app lifecycle
2. Design system: colours, typography, spacing as SwiftUI extensions
3. Shared components: AI Briefing Card, Hero Card, Pill, Tab Bar
4. Tab navigation skeleton (4 tabs, empty views)
5. Core Data stack with all entities
6. Business Profile settings screen

### Phase 2 — Invoicing (highest pain-point value)
1. Invoice data model + CRUD
2. Invoice creation flow (3-step sheet)
3. Invoice list view with status pills
4. PDF generation (HTML template → WKWebView → PDF)
5. Send via email (MFMailComposeViewController)
6. Expense quick-add
7. Monthly income/expense summary

### Phase 3 — Calendar
1. EventKit integration (read/write)
2. Calendar selection screen
3. Week strip + daily agenda
4. Event creation with `.ics` invite option
5. AI Briefing integration

### Phase 4 — Roadmap
1. Milestone + task CRUD
2. Timeline view (default)
3. Board/Kanban view
4. Task interactions (swipe, drag, status changes)
5. AI Briefing integration

### Phase 5 — Metrics (Coming Soon placeholder)
1. "Coming Soon" placeholder screen with blue gradient card
2. Tab bar entry with 📊 icon (functional navigation, placeholder content)

### Phase 6 — Polish
1. AI briefing prompts refined for all 4 tabs
2. Animations (card transitions, shimmer loading, pill taps)
3. Onboarding flow (business profile setup)
4. Notification scheduling (invoice reminders, deadline alerts)
5. CloudKit sync toggle

---

## 12. Decisions Made

| Question | Decision |
|----------|----------|
| App name | **Cleo** |
| Invoice numbering | Single global sequence: `INV-2026-0001`. No per-client sequences. Sequential, no gaps — ATO-friendly. |
| Expense categories | Software, Equipment, Travel, Advertising, Subscriptions, Materials, Other (confirmed) |
| Metrics tab | Deferred to v2. Ships as "Coming Soon" placeholder. |
| Multi-user | Independent app instances. No shared mode. Tony and Cleo each install their own copy. |
| Monetisation | None planned. No StoreKit, no subscriptions, no paywalls. |
| Social media metrics | Deferred to Metrics tab (v2). |

## 13. Remaining Open Questions

1. **Calendar invites**: Do you need to send meeting invites to clients from within the app, or is the calendar purely for your own scheduling? (This determines whether we build the `.ics` share flow in Phase 3.)
2. **Business logo**: Do you have a logo you'd like to use on invoices, or should the PDF just use the business name as text?
3. **Payment details**: What bank details / PayID should be pre-configured as defaults for invoice generation?

---

## 14. What to Reuse vs. Rebuild

### Reuse directly (copy + adapt)
- Design system tokens (colours, typography, spacing)
- AI Briefing Card component (change accent colour per tab)
- Hero Card component
- Pill component
- Tab Bar component
- AI briefing manager (cache, debounce, call caps)
- Core Data stack setup pattern
- Shimmer/loading states

### Rebuild (same pattern, new content)
- Tab views (entirely new content per tab)
- Data models (business entities, not family entities)
- AI prompts (business-savvy tone, not family-friendly tone)
- PDF generation (new for invoicing)
- EventKit integration (same framework, different usage — business calendars vs family calendars)
- Settings screen (business profile vs family profile)

### New (doesn't exist in Family Planner)
- Invoice creation flow
- PDF invoice rendering
- Email send with attachment
- Roadmap timeline + board views
- Metric widget grid system
- Manual metric entry
- Widget configuration mode

---

*This brief is designed to be consumed by Claude Code as a primary reference document. Each section is self-contained. The build order in Section 11 maps to discrete implementation sessions.*
