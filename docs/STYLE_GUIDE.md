# Cleo Style Guide & UX Specification

Reference for all UI patterns, interaction conventions, and visual tokens. **Consult before making any visual or interaction changes.**

---

## 1. Colour Tokens

### Surface Hierarchy

| Token | Value | Usage |
|-------|-------|-------|
| `cleoBackground` | `#0D0B1E` | App background (via `.cleoBackground()`) |
| `cleoCardSurface` | `#181030` | Card backgrounds |
| `cleoElevatedSurface` | `#1C1236` | Elevated cards (non-sheet contexts) |
| Sheet surface | `.ultraThinMaterial` | All sheet/modal backgrounds (glassmorphism) |
| Background glow | `brandAccent.opacity(0.06)` radial | Subtle brand tint on background |

### Text Hierarchy

| Token | Value | Usage |
|-------|-------|-------|
| Primary | `#f0e6ff` / `.cleoPrimaryText` | Headings, important values |
| High | `.white.opacity(0.8)` | Card titles, form input text |
| Mid | `.white.opacity(0.6)` | Subtitles, descriptions, pill text |
| Dim | `.white.opacity(0.4)` | Section labels, placeholders, captions |
| Muted | `.white.opacity(0.3)` | Empty states, disabled text |
| Ghost | `.white.opacity(0.2)` | Faintest labels, column headers |

> **Rule:** Never use arbitrary opacity values. Pick from this scale: `0.2, 0.3, 0.4, 0.6, 0.8, 1.0`.

### Tab Accent Colours

| Tab | Colour | Hex | Soft (background) | Usage |
|-----|--------|-----|-------------------|-------|
| Calendar | Purple | `#b794f6` | `opacity(0.15)` | Dynamic — overridden by `theme.brandAccent` |
| Invoicing | Green | `#00b894` | `opacity(0.15)` | Fixed |
| Roadmap | Amber | `#fb923c` | `opacity(0.15)` | Fixed |
| Metrics | Blue | `#74b9ff` | `opacity(0.15)` | Fixed |

### Surface Opacity Scale (backgrounds)

| Opacity | Usage |
|---------|-------|
| `0.02` | Completed/faded card backgrounds |
| `0.04` | Standard card/row backgrounds |
| `0.06` | Borders, dividers, subtle pill backgrounds |
| `0.08` | Avatar circles, icon containers |
| `0.1` | Disabled button backgrounds, count badges |
| `0.15` | Coloured pill backgrounds (`accent.opacity(0.15)`) |

> **Rule:** Always use `Color.white.opacity(n)` for surface tints, never raw grey values.

---

## 2. Typography

### Font Scale

| Style | Definition | Usage |
|-------|-----------|-------|
| `cleoHeadline` | `.system(.title2, design: .serif).bold()` | AI briefing headlines, page hero text |
| `cleoTitle` | `.title2.bold()` | Card titles, section titles |
| Nav title | `.system(.headline, design: .serif)` | Navigation bar `.principal` |
| Card title | `.subheadline.weight(.semibold)` | List row titles, card headers |
| Section label | `.caption.bold()` + `.tracking(1)` + `.white.opacity(0.4)` | Uppercase section headers (e.g. "DETAILS", "LINE ITEMS") |
| `cleoBody` | `.subheadline` | Body text, descriptions |
| `cleoBadge` | `.caption.bold()` + `.tracking(1.5)` | Badge labels (e.g. "✦ AI BRIEFING") |
| `cleoPill` | `.caption2.weight(.medium)` | Pill text |
| Fine print | `.caption2` | Timestamps, metadata, subtitles |
| Monospaced | `.subheadline.monospaced()` | Currency amounts, invoice numbers |

### Typography Rules

- **Serif** (`design: .serif`): Only for nav bar titles and AI briefing headlines — gives premium feel
- **Tracking**: `1.0` for section labels, `1.5` for badge labels — always paired with `.bold()` and uppercase
- **Numbers**: Use `.monospaced()` for currency, dates, and counts to prevent layout shifts
- Never mix serif and sans-serif within the same card

---

## 3. Spacing & Layout

### Padding Scale

| Value | Usage |
|-------|-------|
| `20` | BriefingCard internal padding, major section padding |
| `16` | Page horizontal margins, between major sections |
| `14` | Standard card internal padding, form section padding |
| `12` | Compact card padding, list row padding |
| `10` | Small card padding (Kanban cards), inner element spacing |
| `8` | Pill horizontal padding, tight spacing between elements |
| `4` | Minimal spacing between closely related elements |

### VStack Spacing

| Context | Spacing |
|---------|---------|
| Between major page sections | `16` |
| Between cards in a list | `12` |
| Between form fields within a section | `8` |
| Between label and content in form section | `10` |
| Between elements inside a card | `6` |
| Between pill items | `8` |

### Corner Radius Scale

| Size | Value | Usage |
|------|-------|-------|
| Hero | `16` | BriefingCard, HeroCard, full-screen cards |
| Standard | `12` | All standard cards, form sections, buttons, inputs |
| Compact | `10` | Small cards (Kanban), secondary containers |
| Accent | `8` | Emoji containers, small badges |

> **Rule:** Default to `12`. Only use `16` for hero-level components, `10` for nested/compact items.

### Border Pattern

Always 1pt stroke:
```swift
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
)
```

---

## 4. Component Patterns

### 4.1 Standard Card

The universal container for content groups:

```swift
content
    .padding(14)
    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
    )
```

**Completed/faded variant:** `.white.opacity(0.02)` background.

### 4.2 Form Section

Labelled container for grouped form inputs:

```swift
VStack(alignment: .leading, spacing: 10) {
    Text("SECTION TITLE")
        .font(.caption.bold())
        .foregroundStyle(.white.opacity(0.4))
        .tracking(1)

    VStack(spacing: 8) {
        // form fields here
    }
    .padding(14)
    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
    )
}
```

### 4.3 Pills

Three pill variants, all using `Capsule()`:

| Variant | Background | Text Colour | Usage |
|---------|-----------|-------------|-------|
| **Colored** | `accent.opacity(0.15)` | `accent` | Status indicators (Overdue, Paid, etc.) |
| **Surface** | `.white.opacity(0.06)` | `.white.opacity(0.6)` | Neutral metadata (dates, counts) |
| **Badge** | `.white.opacity(0.1)` | `.white.opacity(0.6)` | Generic labels |

Pill padding: `.horizontal(8)` + `.vertical(3)`.

### 4.4 Three-Layer Visual Hierarchy (Per Tab)

Every tab follows this structure top-to-bottom:

1. **AI Briefing Card** — Gradient background, sparkle badge, headline, summary, stat pills, shimmer loading
2. **Hero Card** — Dark surface, emoji with bob animation, title/subtitle, pill row
3. **Content Area** — Tab-specific: lists, grids, boards, agendas

This order is sacred. Never rearrange or skip layers.

### 4.5 List Rows

Standard row inside a scrollable list:

```swift
HStack {
    // Left: title + subtitle VStack
    // Right: value/status pill
}
.padding(12)
.background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
```

- Row spacing in parent VStack: `8`
- Always use `12` padding for rows, `14` for standalone cards
- Tap target must cover the full row (use `.contentShape(Rectangle())` if needed)

### 4.6 Empty States

**Inline (inside a card/list area):**
```swift
Text("No invoices yet. Tap + to create one.")
    .font(.subheadline)
    .foregroundStyle(.white.opacity(0.3))
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.vertical, 20)
```

**Full-tab (when no data at all):**
```swift
ContentUnavailableView(
    "No Invoices",
    systemImage: "doc.text",
    description: Text("Tap + to create your first invoice.")
)
```

**Hero card empty variant:**
Use `HeroCardView` with `isEmpty: true` and `emptyMessage:` — compact horizontal layout.

> **Rule:** Every list that can be empty MUST have an empty state. Use inline for card-embedded lists, `ContentUnavailableView` for full-tab empty states.

---

## 5. Interaction Patterns

### 5.1 Add Flow

- **Trigger:** `+` button in toolbar (`.topBarTrailing`)
- **Presentation:** `.sheet` — never push navigation for creation flows
- **Simple items:** Direct form sheet
- **Complex items (invoices):** Multi-step sheet with internal `TabView(.page)` + step indicator

### 5.2 Edit Flow

- **Trigger:** Tap on list row or card
- **Presentation:** `.sheet` — same form as add, pre-populated with existing data
- **Title changes:** "New Invoice" → "Edit Invoice", "Add Milestone" → "Edit Milestone"
- **Save button text:** "Save" (not "Update" or "Done")

### 5.3 Delete Flow

- **Primary method:** Swipe-left on list rows → red "Delete" button
- **Secondary method:** "Delete" button at bottom of edit sheet (red, `role: .destructive`)
- **ALWAYS confirm** before deleting with a confirmation dialog
- Swipe config: `.swipeActions(edge: .trailing, allowsFullSwipe: false)` — never allow full swipe delete

```swift
.confirmationDialog(
    "Delete \"\(item.title)\"?",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) { deleteItem() }
}
```

### 5.4 Sheet / Modal Patterns

#### Standard Form Sheet

```swift
NavigationStack {
    ScrollView {
        VStack(spacing: 16) {
            // form sections
        }
        .padding(16)
    }
    .navigationTitle("Sheet Title")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .bold()
                .disabled(!isValid)
        }
    }
}
.presentationDetents([.medium, .large])
.presentationBackground(.ultraThinMaterial)
```

#### Button Placement Rules

| Position | Placement | Button | Style |
|----------|-----------|--------|-------|
| Top-left | `.cancellationAction` | "Cancel" | Plain text |
| Top-right | `.confirmationAction` | "Save" / "Done" / "Next" | `.bold()`, disabled when invalid |

> **Rule:** NEVER use custom "X" close buttons. NEVER rely on drag-to-dismiss as the only dismiss method. Always provide an explicit Cancel/Done button.

#### Sheet Sizing

| Content | Detent | Notes |
|---------|--------|-------|
| Simple form (3–5 fields) | `[.medium, .large]` | Starts medium, user can pull to large |
| Complex form (6+ fields) | `[.medium, .large]` | Same — medium-first for lighter feel |
| Multi-step flow (invoices) | `[.large]` | Needs space for step navigation |
| Picker/selection | `[.medium]` | Quick selection, easy dismiss |
| Detail/read-only view | `[.medium, .large]` | Starts medium, expand for more |

#### Presentation Background

- **All sheets**: `.presentationBackground(.ultraThinMaterial)` — glassmorphism consistent throughout
- Never use solid `Color.cleoElevatedSurface` for sheet backgrounds

### 5.5 Destructive Actions in Sheets

When an edit sheet includes delete:

```swift
// At the bottom of the form, outside form sections
Section {
    Button("Delete Invoice", role: .destructive) {
        showDeleteConfirmation = true
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.top, 24)
}
```

### 5.6 Navigation Bar (All Tabs)

```swift
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button { showProfile = true } label: {
            Image(systemName: "person.circle")
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    ToolbarItem(placement: .principal) {
        Text("Tab Name")
            .font(.system(.headline, design: .serif))
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button { showAddSheet = true } label: {
            Image(systemName: "plus")
        }
    }
}
```

- Profile icon: always top-left, `person.circle`, `opacity(0.6)`
- Add button: always top-right, `plus` icon
- Title: always serif font in `.principal`

---

## 6. Button Styles

### Primary CTA (full-width)

Used for the main action at the bottom of a form or step:

```swift
Button(action: { /* action */ }) {
    Text("Create Invoice")
        .font(.subheadline.bold())
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cleoInvoicingGreen, in: RoundedRectangle(cornerRadius: 12))
}
.disabled(!isValid)
// Disabled state: .white.opacity(0.1) background, .white.opacity(0.3) text
```

- Colour matches the current tab's accent
- Corner radius: `12`
- Padding: vertical `14`
- Always full-width (`maxWidth: .infinity`)

### Secondary Button (ghost)

Used for alternative actions (Save as Draft, Skip, Back):

```swift
Button("Save as Draft") { /* action */ }
    .font(.subheadline)
    .foregroundStyle(.white.opacity(0.5))
```

- No background
- Reduced opacity text
- Placed below or beside primary CTA

### Toolbar Text Button

Used in navigation bars and sheet toolbars:

```swift
Button("Cancel") { dismiss() }     // Leading — plain weight
Button("Save") { save() }.bold()   // Trailing — bold weight
```

### Icon Button (inline)

Used for add/remove actions within forms:

```swift
Button { addLineItem() } label: {
    Label("Add Line Item", systemImage: "plus")
        .font(.subheadline)
        .foregroundStyle(Color.cleoInvoicingGreen)
}
```

### Destructive Button

```swift
Button("Delete Invoice", role: .destructive) {
    showConfirmation = true
}
```

- Always uses `role: .destructive` (system red styling)
- Always triggers confirmation dialog, never deletes directly

---

## 7. Animation & Transitions

### Standard Transitions

| Context | Animation |
|---------|-----------|
| Step change (multi-step flow) | `.easeInOut(duration: 0.3)` |
| Month/date navigation | `.easeInOut(duration: 0.2)` |
| Theme/colour change | `.easeInOut(duration: 0.2)` |
| Expand/collapse | `.easeInOut(duration: 0.22)` |
| Onboarding step | `.easeInOut` (default duration) |

### Continuous Animations

| Element | Animation |
|---------|-----------|
| HeroCard emoji bob | `.easeInOut(duration: 3).repeatForever(autoreverses: true)`, offset 6pt |
| Briefing shimmer | `TimelineView(.animation)` with sliding `LinearGradient`, `.white.opacity(0.08)` |

### Rules

- Use `withAnimation(.easeInOut(duration: 0.2))` for UI state changes
- **Never** animate list re-layouts (causes jumping) — animate individual elements only
- Keep durations short: 0.2s for quick feedback, 0.3s for page transitions, 3s for ambient effects
- No spring animations — `easeInOut` only for consistency

---

## 8. Haptic Feedback

| Gesture | Feedback |
|---------|----------|
| Tap to select / toggle | `UIImpactFeedbackGenerator(style: .light)` |
| Complete action (mark as paid, done) | `UIImpactFeedbackGenerator(style: .medium)` |
| Long press | `UIImpactFeedbackGenerator(style: .medium)` |
| Destructive action confirmed | `UINotificationFeedbackGenerator().notificationOccurred(.warning)` |

---

## 9. Form Validation

### Inline Validation Rules

- **Save/Next button** is disabled (`.disabled(!isValid)`) until required fields are filled
- Required fields: visually identical to optional — no asterisks or "required" labels
- Error feedback: use the disabled button state as the primary signal — users see the button enable as they complete fields
- **Never** show red error text below fields for missing data (it feels hostile)

### When to Show Explicit Errors

- After a **failed action** (API error, save failure): show an `ErrorBannerView` at the top of the content
- For **format errors** on submit attempt (invalid email, negative amount): brief inline text below the field in `.red.opacity(0.8)`, `.caption` font

```swift
if showEmailError {
    Text("Enter a valid email address")
        .font(.caption)
        .foregroundStyle(.red.opacity(0.8))
}
```

---

## 10. Swipe Actions

### Standard Swipe-Left (Destructive)

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        itemToDelete = item
        showDeleteConfirmation = true
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

### Swipe-Right (Status Change) — Optional

```swift
.swipeActions(edge: .leading, allowsFullSwipe: true) {
    Button {
        markAsDone(item)
    } label: {
        Label("Done", systemImage: "checkmark")
    }
    .tint(.green)
}
```

- **Trailing swipe** (destructive): never allow full swipe, always confirm
- **Leading swipe** (positive action): may allow full swipe for quick completion
- Keep to 1 action per side maximum — don't overload swipe menus

### Recommended Swipe Actions Per Tab

| Tab | Swipe-left (trailing) | Swipe-right (leading) |
|-----|----------------------|----------------------|
| Invoicing (invoices) | Delete (with confirm) | Mark as Paid (`.tint(.green)`, full swipe OK) |
| Invoicing (clients) | Delete (with confirm) | — |
| Roadmap (tasks) | Delete (with confirm) | Mark as Done (`.tint(.green)`, full swipe OK) |
| Roadmap (milestones) | Delete (with confirm) | — |
| Calendar (events) | — (EventKit managed) | — |

---

## 11. Gradient Patterns

### Briefing Card Gradient

Each tab has a predefined gradient (deep accent → mid → surface → card):

```swift
LinearGradient(
    colors: accent.briefingGradientColors,
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Hero Card Gradient

Subtle linear + radial overlay:

```swift
ZStack {
    RoundedRectangle(cornerRadius: 16)
        .fill(LinearGradient(
            colors: accent.heroGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    RadialGradient(
        colors: [accent.color.opacity(0.2), .clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 200
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
}
```

### Background Glow

Applied via `.cleoBackground()` modifier — subtle brand-coloured radial from top-trailing.

---

## 12. Accessibility Notes

- All interactive elements must have a minimum 44×44pt tap target
- Use `.contentShape(Rectangle())` on rows to extend tap area to full width
- Accent colours pass WCAG AA contrast against dark backgrounds — maintain this
- Pill text at `.caption2` size is the smallest allowed — never go smaller
- All icons should have meaningful labels (use `Label(text, systemImage:)`, not bare `Image`)

---

## 13. Dos and Don'ts

### Do

- Use the three-layer hierarchy on every tab
- Use `.cancellationAction` / `.confirmationAction` for toolbar buttons
- Confirm all destructive actions
- Use monospaced font for numbers that change
- Match button accent to the current tab colour
- Provide empty states for every list
- Keep sheets focused — one purpose per sheet

### Don't

- Use "X" close buttons (use "Cancel" or "Done" text)
- Use solid backgrounds for sheets (always use `.ultraThinMaterial` glassmorphism)
- Allow full-swipe delete
- Use spring animations
- Mix serif and sans-serif in the same card
- Add borders to buttons (buttons are borderless, only cards have borders)
- Use raw colour values — always use design tokens
- Show loading spinners — use shimmer for AI, disabled state for saves
- Use `NavigationLink` for creation/edit flows — always use `.sheet`

---

## Quick Reference: Common Values

```
Background:         #0D0B1E
Card surface:       .white.opacity(0.04)
Border:             .white.opacity(0.06), 1pt
Corner radius:      12 (standard), 16 (hero), 10 (compact)
Card padding:       14 (standard), 12 (rows), 20 (briefing)
Page margins:       16
Primary text:       #f0e6ff
Dim text:           .white.opacity(0.4)
Pill bg:            accent.opacity(0.15)
Button radius:      12
Button padding:     vertical 14
Animation:          .easeInOut(duration: 0.2)
Nav bar bg:         .ultraThinMaterial
Sheet bg:           .ultraThinMaterial
Cancel:             .cancellationAction (top-left)
Save:               .confirmationAction (top-right, .bold())
```
