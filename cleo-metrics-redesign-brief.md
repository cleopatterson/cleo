# Cleo — Metrics Tab Redesign

## Summary

Restructure the Metrics tab to lead with financial performance, pushing time tracking into a secondary position. The top of the screen should answer "how is my business going?" at a glance.

---

## What's Changing

### Current Layout
1. AI Briefing (time tracking focused — hours, clients, sessions)
2. Top Client card
3. Hours by Client chart

### New Layout
1. **Monthly briefing card** — profit headline, revenue/expenses summary, trend vs last period
2. **Profit & Loss card** — net profit hero number + revenue vs expenses side-by-side bars
3. **Time Tracking section** — existing top client + hours by client charts, unchanged

---

## Screen: Metrics Tab

**Reference prototype:** `cleo-metrics-final.html`

### 1. Monthly Briefing Card

Replaces the "AI Briefing" label with the current month (e.g. "✦ March 2026"). This grounds the data in a specific period rather than an abstract AI label.

- **Label:** `✦ [Month] [Year]` (e.g. "✦ March 2026") — teal, uppercase, 11px
- **Headline:** Profit summary in plain language (e.g. "$26,468 profit this month")
- **Subtext:** AI-generated context — trend vs last period, top earner, notable changes
- **Tags:** Revenue total, Expenses total, % change vs last period
- **Data period:** Rolling 30 days

### 2. Profit & Loss Card

- **Header:** "Profit & Loss" label (left) + "Last 30 days" badge (right)
- **Hero number:** Net Profit, centred, 32px bold. Teal if positive, red if negative.
- **Trend line:** "↑ X% vs previous period" below the hero number
- **Bar comparison:**
  - Revenue bar — teal fill (rgba 62,207,154, 0.25), amount label inside
  - Expenses bar — red fill (rgba 240,70,90, 0.25), amount label inside
  - Both bars share the same track width; fill width is proportional (revenue as 100% baseline)
  - Bar height: 28px, border-radius 8px
  - Label column: 70px wide, left-aligned

### 3. Time Tracking Section

Existing components, unchanged in design. Moved below the financial cards under a "Time Tracking" section label.

- **Top Client card** — client name, hours, % of week, trophy icon, session/total tags
- **Hours by Client** — horizontal bar chart, client names left, hours right

---

## Briefing Card Logic

The briefing headline and subtext are AI-generated based on financial data:

| Scenario | Headline example | Subtext example |
|---|---|---|
| Profitable, trending up | "$26,468 profit this month" | "Revenue up 34% vs last 30 days. Service Seeking is your top earner." |
| Profitable, trending down | "$12,000 profit this month" | "Down 18% vs last month. Expenses increased — check subscriptions." |
| Break even | "Breaking even this month" | "Revenue and expenses are matched. Consider following up on outstanding invoices." |
| Loss | "$2,400 loss this month" | "Expenses exceeded revenue. Two large invoices are still outstanding." |

---

## Design Tokens

Same as the invoicing redesign — see `cleo-invoicing-redesign-brief.md` for the full token list. Additional tokens for this screen:

```
Revenue bar fill:   rgba(62, 207, 154, 0.25)
Expense bar fill:   rgba(240, 70, 90, 0.25)
Profit positive:    #3ecf9a
Profit negative:    #f0465a
Bar height:         28px
Bar radius:         8px
Hero number size:   32px, weight 700
```

---

## Out of Scope (for now)
- Period selector (toggle between months, quarters, rolling periods)
- Drill-down into revenue by client or expense categories
- Monthly trend chart (considered but deferred — option C in explorations)
- Expense categorisation
- Tax estimates / BAS summary
