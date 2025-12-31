# Technical Review: Multiple Properties Feature Specifications

**Reviewer:** Claude  
**Date:** 2025-12-31  
**Drafts Reviewed:**
- Draft A: Gemini (`draft-gemini.md`)
- Draft B: Codex (`draft-codex-x71bz.md`)

---

## Executive Summary

Both specifications address the core requirement of displaying multiple GA4 properties in the menu bar, but take significantly different approaches in depth and technical detail. **Draft B (Codex)** provides substantially more implementation detail, risk mitigation strategies, and considers edge cases more thoroughly. **Draft A (Gemini)** is more straightforward but lacks critical implementation details, particularly around rendering constraints and error handling.

**Critical Issues Found:**
1. Both specs underestimate the MenuBarExtra rendering constraints in macOS
2. Neither spec adequately addresses GA4 API quota management with concrete numbers
3. Migration strategy needs more robustness (both specs mention it but lack detail)
4. Concurrent network request management is vague in both specs
5. Neither spec addresses what happens when properties are deleted in GA4
6. Space constraints and overflow handling need clearer max limits

---

## Draft A Review: Gemini's Specification

### 1. Major Issues (Blocking)

#### 1.1 MenuBarExtra Rendering Architecture is Unclear
- **Line 36-38:** The spec acknowledges that a single `MenuBarExtra` creates ONE item and suggests displaying all properties "side-by-side within the single menu bar item's view" with example `[ 👤 120 ] [ 🛒 45 ]`
- **Problem:** This is technically feasible but the spec doesn't explain HOW. SwiftUI MenuBarExtra label views are severely constrained - you can't just put arbitrary views in them without using tricks like `ImageRenderer`
- **Current codebase:** Uses simple `HStack` with `Image` and `Text` in `MenuBarView.swift:44-50`
- **Impact:** Implementation will likely fail or require significant research to figure out the rendering approach
- **Fix Required:** Explicitly specify using `ImageRenderer` to convert SwiftUI view to NSImage, or acknowledge that the HStack approach may have limitations

#### 1.2 No Concurrency Strategy for Network Requests
- **Line 99:** States "iterates `store.properties`, calls `ReportLoader` for each" but provides no details
- **Problem:** Current `ReportLoader` (lines 51-74 in ReportLoader.swift) returns a publisher via callback. Firing N of these simultaneously could:
  - Exhaust GA4 quotas instantly
  - Create race conditions in state updates
  - Block the main thread if not properly managed
- **Current pattern:** Single property with Combine publisher that updates @Published state
- **Missing:** Task groups, semaphores, or sequential execution strategy
- **Fix Required:** Specify whether to use `TaskGroup`, dispatch groups, or sequential fetching with clear concurrency limits

#### 1.3 Migration Logic is Superficial
- **Line 132:** "On first launch, we must migrate this single ID into the new `configuredProperties` array"
- **Problem:** No code, no error handling, no rollback strategy if migration fails
- **Edge case not covered:** What if `selectedPropertyId` points to a deleted property?
- **Missing:** When does migration happen? In `ConfigurationStore.init`? Who fetches the property metadata (display name)?
- **Fix Required:** Detailed migration algorithm with error states and fallback behavior

#### 1.4 ConfiguredProperty Model Missing Critical Fields
- **Lines 52-61:** Model includes `id`, `propertyId`, `propertyName`, `icon`, `label`, `color`
- **Missing fields:**
  - `accountDisplayName` (needed for UI display, already in current Property model)
  - `lastUpdated` timestamp (for stale data detection)
  - `isEnabled` or similar (for future show/hide toggles)
- **Problem:** Spec says line 59 has `color` for "future proofing" but omits fields that are immediately needed
- **Fix Required:** Add `accountDisplayName: String` and consider `lastFetchedAt: Date?`

### 2. Likely Edge Cases / Failure Modes

#### 2.1 Property Deletion in GA4
- **Not addressed:** User configures 3 properties, then deletes one in GA4 dashboard
- **Current behavior:** Single property selection just shows "Error!" but doesn't explain why
- **Expected failure:** App will get 404 or permission error, user sees cryptic error state
- **Fix Required:** Add health check logic, graceful degradation, and UI to remove stale properties

#### 2.2 Network Offline State
- **Line 44:** Mentions "fetching N properties should not block the main thread" but doesn't address offline behavior
- **Current code:** `MenuBarViewModel` has `NWPathMonitor` that triggers refresh when network returns
- **Gap:** No mention of how `MultiMenuBarViewModel` handles partial failures (2 of 3 properties succeed)
- **Fix Required:** Specify retry logic, stale data display, and per-property error states

#### 2.3 AppStorage JSON Encoding Failure
- **Line 66:** Suggests using `@AppStorage` wrapper that handles JSON
- **Problem:** `@AppStorage` doesn't natively support complex types. Custom wrapper needed but not specified
- **Current pattern:** App uses `@AppStorage` only for primitives (String, Int, Bool)
- **Likely failure:** Developer writes naive JSON encoding that breaks with special characters in property names
- **Fix Required:** Provide example wrapper or explicitly state to use `UserDefaults.data(forKey:)` directly

#### 2.4 Icon/Label Input Validation
- **Line 58:** `icon` field is just a String for SF Symbol name
- **Gap:** No validation that the symbol exists, no fallback for invalid symbols
- **Line 58:** `label` is optional String with comment "max ~3 chars" but no enforcement
- **Impact:** UI could display broken symbols or overflow labels
- **Fix Required:** Add validation requirements and fallback behavior

### 3. Complexity / Cost Risks

#### 3.1 Settings UI Complexity Underestimated
- **Line 92:** "Each row in the list has an 'Edit' button to change the icon"
- **Reality:** Building a good SF Symbol picker is non-trivial. Draft mentions "simple SF Symbol picker or preset list" but doesn't decide
- **Estimate:** 3-4 hours for curated list, 2+ days for searchable picker
- **Risk:** Developer picks the hard path and blows timeline
- **Mitigation:** Spec should mandate curated list (≤20 symbols) for v1

#### 3.2 No Performance Benchmarks
- **Gap:** No mention of acceptable latency for N properties
- **Current:** Single property feels instant (< 1s typically)
- **Risk:** 5 properties × 1s each = 5s refresh if sequential, or quota exhaustion if parallel
- **Fix Required:** Set performance budget (e.g., "all properties must complete within 3s, use timeout per request")

#### 3.3 Testing Scope Too Narrow
- **Lines 141-147:** Manual tests only, no mention of unit tests
- **Missing:** 
  - Unit tests for JSON encoding/decoding
  - Mock tests for API failures
  - UI tests for drag-drop
- **Risk:** Regressions in core functionality
- **Fix Required:** Expand test plan to include automated tests

### 4. Missing Requirements

#### 4.1 Error State Differentiation
- Current UI shows generic "Error!" for any failure
- Spec doesn't require distinguishing between:
  - Network offline
  - Auth token expired
  - Property not found (404)
  - Quota exceeded (429)
  - Invalid property permissions
- **Impact:** Poor debugging experience for users
- **Fix Required:** Define per-property error states and UI representations

#### 4.2 Rate Limiting / Backoff Strategy
- **Line 45:** Mentions "handle quota errors gracefully (e.g., exponential backoff or user warning)" but provides no algorithm
- **Gap:** No mention of what the exponential backoff parameters are
- **Gap:** No mention of whether backoff is per-property or global
- **Fix Required:** Specify backoff algorithm (e.g., "start at 1min, double each retry, max 30min")

#### 4.3 Accessibility Requirements
- **Completely missing** from spec
- Current code has no VoiceOver labels
- Multi-property UI will be harder to navigate with assistive tech
- **Fix Required:** Add section on VoiceOver labels, keyboard navigation, and high-contrast mode

#### 4.4 Maximum Property Limit
- **Line 131:** "perhaps add a 'compact mode' option later" and "limit the initial UI to maybe max 5 properties"
- **Problem:** Uses "maybe" and "perhaps" - not decisive
- **Gap:** No enforcement mechanism specified
- **Fix Required:** Decide on hard limit (recommend 5) and specify where/how to enforce

### 5. Suggested Changes

1. **Section 4 (Proposed Design):** Add subsection "4.5 Rendering Strategy" explaining `ImageRenderer` approach with code example
2. **Section 4.1 (ConfigurationStore):** Add method signatures for migration: `func migrateFromLegacyStorage() throws`
3. **Section 4.2 (MultiMenuBarViewModel):** Add property `@Published var propertyErrors: [PropertyID: Error]` for per-property error tracking
4. **Section 6 (Risks):** Add row for "Property deletion in GA4" with mitigation strategy
5. **Section 7 (Rollout):** Add Phase 0 for prototyping the rendering approach (risk reduction)
6. **Section 8 (Testing):** Add unit test requirements and acceptance criteria
7. **Section 10 (Open Questions):** These should be ANSWERED in the spec, not left open:
   - Icon Selection: Mandate curated list of 20 symbols for v1
   - API Quotas: Research and document actual GA4 limits with citations

### 6. Questions to Resolve

1. **Rendering Approach:** Will `HStack` work in MenuBarExtra label, or must we use `ImageRenderer`? (Needs prototype)
2. **Concurrent vs Sequential Fetching:** For N=5 properties, parallel or sequential? What's the measured quota impact?
3. **Migration Failure Recovery:** If migration fails, should app fall back to empty config or try to preserve old `selectedPropertyId`?
4. **Property Limit Enforcement:** Should there be a hard limit (5) or soft limit with warning (>3)?
5. **Error State Display:** Should each property show individual error in menu bar, or just one aggregated error indicator?
6. **Icon Picker UX:** Sheet, popover, or inline dropdown? Current `PropertySelectView` uses `Picker` - consistent?

---

## Draft B Review: Codex's Specification

### 1. Major Issues (Blocking)

#### 1.1 ImageRenderer Strategy May Not Work as Described
- **Line 92-94:** Spec mandates using `ImageRenderer` to convert SwiftUI HStack into NSImage for MenuBarExtra label
- **Citation:** References StackOverflow 77150551
- **Problem:** MenuBarExtra in macOS 13+ uses SwiftUI natively. Converting to NSImage might work but could lose:
  - System font scaling
  - Dark mode automatic adaptation
  - Dynamic type support
- **Risk:** Solution may look pixelated or wrong on Retina displays if DPI not handled correctly
- **Fix Required:** Add validation step to ensure ImageRenderer output is pixel-perfect. Consider alternative: use native SwiftUI Label with custom layout if possible

#### 1.2 Concurrency Limiter Implementation Ambiguous
- **Line 81:** "use Swift structured concurrency with `Task { await withTaskGroup }` and `Semaphore` or `AsyncStream` to cap simultaneous requests"
- **Problem:** Mixing `Semaphore` (GCD/DispatchQueue) with structured concurrency is an anti-pattern
- **Swift 5.5+:** Should use `TaskGroup` with manual limiting (only adding N tasks at a time), not semaphores
- **Current codebase:** Uses Combine publishers, not async/await
- **Impact:** Major refactor required that's not acknowledged in rollout plan
- **Fix Required:** Either:
  1. Stick with Combine and use `Publishers.MergeMany` with `maxPublishers` parameter, OR
  2. Explicitly call out the Combine → async/await migration as a prerequisite phase

#### 1.3 ConfigurationStore Architecture Overcomplicated
- **Lines 85-87:** `ConfigurationStore` provides `@MainActor` wrappers for UI calls
- **Problem:** The spec stores data in `@AppStorage` (which is already main-thread bound) but then adds manual `@MainActor` wrappers
- **Confusion:** It's unclear whether `ConfigurationStore` is an `@ObservableObject` or a `@MainActor` class
- **Current pattern:** ViewModels are `ObservableObject`, views observe them
- **Risk:** Mixing `@MainActor` and `@AppStorage` could cause subtle SwiftUI update bugs
- **Fix Required:** Clarify the threading model. Recommend: make store a pure `ObservableObject` without manual actor annotations

#### 1.4 Schema Uses Nested Configuration Version
- **Lines 150-167:** Persistence schema has top-level `configurationVersion` wrapping `properties` array
- **Problem:** Schema shown has `{"configurationVersion": 1, "properties": [...]}` but the struct (lines 120-134) doesn't match this shape - `ConfiguredProperty` doesn't have a wrapper
- **Inconsistency:** Line 70 says store in `@AppStorage("configuredProperties")` but schema example suggests a wrapper object
- **Impact:** Implementation confusion - which shape is correct?
- **Fix Required:** Either:
  1. Define a `ConfigurationContainer` struct with version + properties array, OR
  2. Store version separately in `@AppStorage("configurationVersion")` and keep properties flat

### 2. Likely Edge Cases / Failure Modes

#### 2.1 Menu Bar Width Calculation Fragile
- **Line 39:** `maxMenuBarWidth` user preference default 140pt
- **Problem:** 140pt is arbitrary. macOS menu bar space available varies by:
  - Screen resolution
  - Other menu bar items
  - Notch on newer MacBooks
- **Gap:** No dynamic measurement of available space
- **Likely failure:** User sets 140pt but only has 100pt available due to other apps
- **Fix Required:** Either measure available space dynamically using `NSStatusItem` positioning APIs, or make the limit relative (e.g., "max 5 properties" instead of pixel width)

#### 2.2 Overflow "+N" Pill Interaction Undefined
- **Line 96:** "clicking pill opens dropdown anchored to the MenuBarExtra"
- **Problem:** MenuBarExtra already opens a dropdown when clicked. How do you intercept clicks on a *part* of the rendered image?
- **Technical gap:** If using `ImageRenderer` to create a single NSImage, you can't have sub-regions with different click handlers
- **Current code:** MenuBarExtra label is not interactive except for whole-item click (line 26-31 in DataBarApp.swift)
- **Fix Required:** Clarify that overflow scenario requires either:
  1. Showing truncated properties with "..." suffix (no click), OR
  2. Not using ImageRenderer and accepting layout constraints

#### 2.3 Per-Property "isShownInMenuBar" Toggle Creates Confusion
- **Line 26, Line 132:** `isShownInMenuBar` field for "future partial displays" and toggle visibility
- **Problem:** If a property is configured but hidden, what's the point? User can just delete it.
- **UX confusion:** Is this "hidden but still fetching" or "hidden and not fetching"?
- **Gap:** Spec doesn't explain the use case for this flag
- **Fix Required:** Either remove this field as premature optimization, OR clearly explain the workflow (e.g., "temporarily hide without losing config")

#### 2.4 Icon Validation Reference Unclear
- **Line 34:** "manual symbol entry with validation via `SFSymbolsValidation` helper"
- **Problem:** No such API exists in Apple frameworks
- **Assumption:** Spec expects custom validation helper, but doesn't define it
- **Gap:** How to validate? Check if `UIImage(systemName:)` returns non-nil? (Note: `UIImage` is iOS, macOS uses `NSImage`)
- **Fix Required:** Provide actual validation approach: `NSImage(systemSymbolName:accessibilityDescription:) != nil`

#### 2.5 Migration Timing Risk
- **Line 70:** "migration: on first launch with empty `configuredProperties` but non-empty `selectedPropertyId`"
- **Problem:** What if user has v1, upgrades to v2 with multi-property, THEN downgrades back to v1?
- **Gap:** No rollback consideration. Old version will still look for `selectedPropertyId` which was deleted
- **Risk:** Version ping-pong breaks app state
- **Fix Required:** Don't delete `selectedPropertyId` until after successful migration confirmation. Keep both keys for 1-2 release cycles

#### 2.6 Drag Handle Hover State Implementation
- **Line 100:** `.moveDisabled(!rowDragHandleHovered)` pattern from nilcoalescing.com
- **Problem:** SwiftUI `List` + `.onMove` doesn't natively support conditional move enabling per row
- **Gap:** Spec references external pattern but doesn't provide implementation detail
- **Risk:** Developer wastes time trying to implement this, or skips it silently
- **Fix Required:** Either provide full code example, OR simplify to "always allow drag from any part of row" (acceptable UX)

### 3. Complexity / Cost Risks

#### 3.1 Six-Week Rollout is Optimistic
- **Section 7:** Proposes 6-week schedule with week-by-week breakdown
- **Reality check:**
  - Week 1: Foundation - realistic
  - Week 2: ViewModel & networking with concurrency rewrite - **Likely 2 weeks** if converting to async/await
  - Week 3: Menu bar UI with ImageRenderer + overflow logic - **Could expand to 2 weeks** with polish
  - Week 4: Settings UI with drag-drop - realistic
  - Week 5: Polish & accessibility - **Often bleeds into week 6**
  - Week 6: QA - realistic but will find bugs from earlier weeks
- **Total estimate:** 7-9 weeks more realistic for solo developer
- **Mitigation:** Add 20% buffer, or descope Week 5 polish items to post-launch

#### 3.2 Over-Engineering with Feature Flag
- **Line 191:** "staged release with feature flag (UserDefaults `multiPropertyEnabled`)"
- **Problem:** Feature flag adds:
  - Branching logic throughout code
  - Testing burden (2× test matrix: flag on/off)
  - Tech debt to remove later
- **Context:** This is a small app, not a large-scale SaaS
- **Risk:** Feature flag complexity outweighs benefits for a menu bar app with hundreds (not millions) of users
- **Fix Required:** Remove feature flag, just ship beta via GitHub releases and promote to stable after 1-2 weeks

#### 3.3 Snapshot Testing Overhead
- **Line 195:** "Snapshot tests: `MenuBarMetricsStrip` in light/dark, overflow states, error badges"
- **Cost:** Setting up snapshot testing infrastructure (SwiftSnapshotTesting library, CI integration, reference images)
- **Benefit:** Catches visual regressions automatically
- **Reality:** For 5-6 snapshot tests, infrastructure overhead ~1-2 days
- **Decision:** Worthwhile if planning long-term maintenance, but could be deferred to post-v1
- **Fix Required:** Move snapshot tests to "Nice to Have" or "Phase 2" section

### 4. Missing Requirements

#### 4.1 Quota Numbers Need Concrete Data
- **Line 50:** "assume default 10 QPS per property"
- **Problem:** This is an assumption, not documented GA4 API limit
- **Reality:** GA4 Data API quotas are complex:
  - Per-property quotas (tokens per day)
  - Concurrent request limits
  - Rate limits (requests per second)
- **Gap:** Spec doesn't cite official Google documentation
- **Impact:** Could design for wrong quota model
- **Fix Required:** Research and cite actual GA4 quotas from https://developers.google.com/analytics/devguides/reporting/data/v1/quotas

#### 4.2 Offline Caching Retention Undefined
- **Line 212 (Open Question 5):** "How long should we retain last-known values before marking them 'stale'?"
- **Problem:** This is left as open question but directly impacts implementation
- **Current code:** No caching - shows "Loading..." every time
- **Recommendation:** 5-10 minutes stale threshold is reasonable for real-time data
- **Fix Required:** Answer this question with specific timeout value

#### 4.3 Localization Strategy Incomplete
- **Line 53:** "Localization: Keep label text user-entered; system strings must remain localizable"
- **Gap:** Spec doesn't list which strings need localization
- **Missing:** 
  - How to localize "users" suffix (singular/plural)
  - Error messages
  - Settings UI labels
- **Current code:** All strings hardcoded in English (MenuBarView.swift:38)
- **Fix Required:** Add localization strings table or defer to post-v1 (document decision)

#### 4.4 Dark Mode Testing Not in Test Plan
- **Line 195:** Mentions snapshot tests for light/dark but not in manual test checklist
- **Gap:** Manual test plan (lines 194-199) doesn't include:
  - Toggle system dark mode while app running
  - High contrast mode
  - Reduced transparency
- **Fix Required:** Add accessibility testing checklist

### 5. Suggested Changes

1. **Section 4.1 (Architecture):** Simplify to pure Combine flow (no async/await migration) OR add Phase 0 for concurrency refactor
2. **Section 4.2 (Storage):** Flatten schema - no wrapper object, just store array directly with separate version key
3. **Section 4.4 (Rendering):** Add fallback plan if ImageRenderer doesn't work well: "If rendering quality issues, revert to SwiftUI Label with truncation"
4. **Section 4.5 (Settings):** Remove drag-handle hover complexity, allow drag from anywhere in row (simpler UX)
5. **Section 5.1 (ConfiguredProperty):** Remove `isShownInMenuBar` field (YAGNI), remove `order` field (redundant with array order)
6. **Section 6 (Risks):** Add "Concurrency model complexity" risk with mitigation "Stick to Combine for v1"
7. **Section 7 (Rollout):** Adjust timeline to 8-9 weeks, remove feature flag, move snapshot tests to Phase 2
8. **Section 8 (Testing):** Add dark mode and accessibility to manual test checklist
9. **Section 10 (Open Questions):** Answer questions 2-5 before implementation starts, don't leave them open

### 6. Questions to Resolve

1. **ImageRenderer vs Native SwiftUI:** Which renders better on Retina displays? (Needs prototype)
2. **Concurrency Model:** Combine or async/await? If async/await, is rollout timeline adjusted to include migration?
3. **Overflow UI:** Is interactive "+N" pill feasible with ImageRenderer approach? If not, what's Plan B?
4. **GA4 Quotas:** What are the ACTUAL documented quota limits? (Needs research with citations)
5. **Property Limit:** Hard limit of 5, or soft limit with warning? Should users be able to bypass?
6. **Migration Safety:** Should old `selectedPropertyId` key be preserved for rollback compatibility?
7. **Feature Flag Value:** Is feature flag worth the complexity for this app's scale?

---

## Comparative Analysis

| Aspect | Draft A (Gemini) | Draft B (Codex) | Winner |
|--------|------------------|-----------------|--------|
| **Clarity** | Straightforward, easier to read | Dense, more technical jargon | A |
| **Completeness** | Missing key implementation details | Covers most aspects thoroughly | B |
| **Technical Accuracy** | Acknowledges MenuBarExtra limitations but vague on solution | Proposes specific solutions but some are questionable (ImageRenderer, Semaphore) | Tie |
| **Risk Mitigation** | Basic risk table, minimal mitigation | Detailed risks with specific mitigations | B |
| **Implementability** | Requires significant research/decisions during implementation | More prescriptive but some prescriptions are wrong | Tie |
| **Testing Strategy** | Manual tests only, too narrow | Comprehensive test plan but snapshot tests may be overkill | B |
| **Timeline Realism** | 4 phases, no time estimates | 6 weeks detailed breakdown, but optimistic | B |
| **Edge Case Coverage** | Weak - many scenarios not considered | Strong - considers offline, errors, overflow, etc. | B |
| **Schema Design** | Simple, but missing critical fields | More complete but has inconsistency (wrapper object) | B |
| **Accessibility** | Completely missing | Covered in multiple sections | B |
| **Localization** | Not mentioned | Addressed but incomplete | B |

**Overall Assessment:**
- **Draft B (Codex)** is significantly more thorough and shows deeper consideration of implementation challenges
- However, Draft B has some technical issues (Semaphore + async/await, ImageRenderer assumptions) that need correction
- **Draft A (Gemini)** is more readable but too high-level to implement from
- **Recommendation:** Use Draft B as base, incorporate clarity from Draft A, fix technical issues identified above

---

## Top Priority Fixes for Both Drafts

### Critical (Must Fix Before Implementation)
1. **Rendering Strategy:** Prototype and validate whether `ImageRenderer` or native SwiftUI Label works best for multi-property display
2. **Concurrency Model:** Decide between Combine (current) vs async/await (new), adjust scope accordingly
3. **GA4 Quota Research:** Get actual quota limits from Google docs, design backoff strategy with real numbers
4. **Migration Robustness:** Define detailed migration algorithm with error handling and rollback safety
5. **Property Limit Enforcement:** Hard-decide on max limit (recommend 5) and where to enforce (UI vs data layer)

### High Priority (Should Fix)
6. **Schema Consistency:** Align struct definition with persistence JSON format (flat vs wrapped)
7. **Per-Property Error States:** Design how errors are displayed (individual vs aggregate)
8. **Overflow Behavior:** Define what happens when properties exceed menu bar space (truncate vs cycle vs hide)
9. **Drag-Drop UX:** Simplify to standard List behavior, avoid complex hover-state patterns
10. **Testing Scope:** Balance thorough testing with development timeline

### Medium Priority (Nice to Have)
11. **Accessibility Checklist:** Define VoiceOver labels and keyboard navigation
12. **Localization Plan:** Decide if v1 includes i18n or defers to later
13. **Dark Mode Testing:** Add to manual test plan
14. **Icon Picker UX:** Curated list (20 symbols) for v1, defer searchable picker
15. **Telemetry Events:** Define what events to log for debugging/analytics

---

## Recommendation

**For Implementation:** Start with **Draft B (Codex)** as the primary reference due to its thoroughness, but:

1. **Simplify concurrency:** Stick with Combine pattern for v1, defer async/await migration
2. **Validate rendering:** Build prototype of multi-property display in first 2 days
3. **Fix schema:** Use flat array storage, separate version key
4. **Answer open questions:** Don't leave questions unanswered - decide and document
5. **Adjust timeline:** Plan for 8-9 weeks with solo developer, or 6 weeks with pair

**Use Draft A for:** Reference on clear communication style, but flesh out missing details using Draft B's depth.

