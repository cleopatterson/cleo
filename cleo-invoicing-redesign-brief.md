# Cleo — Invoicing Workflow Redesign

> **⚠ ARCHIVED — This redesign brief has been implemented. Refer to `CLAUDE.md` and the current codebase for the live invoicing flow.**

## Summary

Redesign the Money tab invoicing flow to reduce friction. The current flow requires 6 screens to create a simple invoice. The new flow offers two paths: a **Quick Invoice** (1-tap from Money tab) and a **"+" button** path — both landing on the same single-screen creator.

---

## What's Changing

### Current Flow (6 screens)
`+ button → Invoice/Expense picker → "Open Invoice Creator" → Client & Details → Line Items → Preview → Email & Send`

### New Flow (2 screens)
**Quick path:** `Tap client card → Single-screen creator (pre-filled) → Preview & Send`

**Full path:** `+ button → Single-screen creator (empty) → Preview & Send`

---

## Screen 1: Money Tab

**Reference prototype:** `money-tab-final.html`

### Layout (top to bottom)
1. **AI Briefing card** — unchanged, shows outstanding summary + smart nudges
2. **Quick Invoice section** — horizontal scrollable row of client cards
3. **Invoices list** — full invoice history (no stats row between cards and list)

### Quick Invoice Cards
- **Size:** 156px wide, 14px padding, 14px border-radius
- **Content per card:** Client avatar (30px, rounded 8px) + name, last invoice amount (hero number, 20px bold), invoice ref + date, smart nudge line
- **Card types:**
  - **Pinned clients** — green dot on avatar, always appear first
  - **Smart suggestions** — Cleo surfaces clients based on invoicing patterns (e.g. "✦ Monthly due")
  - **"+ New" card** — dashed border, 100px wide, opens empty creator
- **Behaviour:** Horizontal scroll, shows ~2.3 cards before scroll. 3-4 client cards + the New card.
- **Data source:** Pinned clients first, then sorted by recency. Smart nudge logic: if client has a recurring pattern (e.g. monthly), show "✦ Monthly due". Otherwise show "X days ago".

### Tapping a Quick Invoice Card
Opens Screen 2 (Invoice Creator) **pre-filled** with:
- Client name, email, address from saved client record
- Invoice # auto-incremented
- Date = today, Due = today + client's default terms
- Line items copied from the client's most recent invoice
- "✦ Pre-filled from your last invoice" banner shown

---

## Screen 2: Invoice Creator (Single Screen)

**Reference prototype:** `invoice-create-final.html`

### Two entry states

| Entry point | Toggle default | Client | Line items | Banner |
|---|---|---|---|---|
| **"+" button** | Invoice selected | Empty — show selector + recent client chips | Empty — 1 blank row | None |
| **Quick Invoice card** | Invoice selected | Pre-filled — show client header | Pre-filled from last invoice | "✦ Pre-filled from your last invoice" |

### Layout (top to bottom)
1. **Nav bar** — Cancel (left), title "New" or "New Invoice" (centre)
2. **Invoice / Expense toggle** — segmented control, full width
3. **Client section** — either:
   - *Empty state:* "Select or add client" tap target + recent client chips below (SS, AP, HC)
   - *Pre-filled:* Client avatar + name + email header
4. **Smart banner** (pre-filled only) — "✦ Pre-filled from your last invoice"
5. **Invoice details** — 2×2 grid: Invoice # (auto, teal, readonly), Terms (default Net 14), Date (today), Due (calculated)
6. **Line items** — card per item: description input, qty × price = line total. Remove button (×) per item. "+ Add Line Item" dashed button below.
7. **Totals card** — Subtotal, GST (10%), Total (teal, bold)
8. **Actions:**
   - Primary: "✉ Preview & Send" (shows total amount when pre-filled, e.g. "✉ Preview & Send — $220.00")
   - Secondary row: "💾 Draft" + "📄 PDF" side by side

### Toggle Behaviour
- **Invoice** selected: Shows client, invoice details, line items, totals, send actions
- **Expense** selected: Switches to expense entry form (separate spec — not covered here)

### Client Chip Behaviour (empty state)
- Tapping a recent client chip fills in: client details, default terms, and pre-loads line items from their last invoice (same as tapping a Quick Invoice card)
- Tapping "Select or add client" opens full client picker/search

### Smart Defaults
- Invoice # auto-increments from the last invoice number
- Date defaults to today
- Terms default to the user's most common setting (Net 14)
- Due date auto-calculates from Date + Terms
- All fields are editable if the user taps them

---

## Design Tokens

```
Background:       #0d1117
Card:             #151b23
Input:            #1a2230
Border:           #1e2636
Teal:             #3ecf9a
Teal dim:         rgba(62, 207, 154, 0.12)
Text primary:     #e8ecf1
Text secondary:   #8893a4
Text muted:       #555f6e
Amber:            #f0a946
Amber dim:        rgba(240, 169, 70, 0.12)
Purple:           #a78bfa
Purple dim:       rgba(167, 139, 250, 0.12)
Red:              #f0465a
Font:             DM Sans
```

---

## Out of Scope (for now)
- Expense creation flow (behind the toggle)
- Invoice preview / PDF generation screen
- Email composition screen
- Client management (add/edit/delete)
- Recurring invoice automation
- Batch invoicing
