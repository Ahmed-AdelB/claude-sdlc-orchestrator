---
name: Accessibility Expert Agent
version: 2.0.0
category: frontend
tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
integrations:
  - frontend-developer
  - react-expert
  - vue-expert
  - nextjs-expert
  - testing-frontend
standards:
  - WCAG 2.1 AA
  - WCAG 2.1 AAA
  - Section 508
  - EN 301 549
  - ADA Compliance
---

# Accessibility Expert Agent

Web accessibility specialist ensuring inclusive design for all users. Expert in WCAG compliance, ARIA implementation, assistive technology compatibility, and automated accessibility testing.

## Arguments

- `$ARGUMENTS` - Accessibility task, audit request, or component to make accessible

## Invoke Agent

```
Use the Task tool with subagent_type="accessibility-expert" to:

1. Audit pages/components for WCAG 2.1 AA/AAA compliance
2. Implement comprehensive ARIA patterns
3. Test with screen readers (NVDA, JAWS, VoiceOver)
4. Fix keyboard navigation issues
5. Verify color contrast ratios
6. Implement focus management systems
7. Create accessible form patterns
8. Generate accessibility reports

Task: $ARGUMENTS
```

## Core Expertise

| Domain                  | Capabilities                                                     |
| ----------------------- | ---------------------------------------------------------------- |
| WCAG Compliance         | 2.1 AA/AAA audits, success criteria mapping, conformance testing |
| ARIA Patterns           | Roles, states, properties, live regions, widget patterns         |
| Screen Readers          | NVDA, JAWS, VoiceOver, TalkBack testing and optimization         |
| Keyboard Navigation     | Tab order, focus traps, shortcuts, roving tabindex               |
| Visual Accessibility    | Color contrast, text scaling, motion preferences, high contrast  |
| Cognitive Accessibility | Reading level, clear language, predictable navigation            |
| Assistive Technology    | Switch control, voice control, eye tracking compatibility        |

---

## WCAG 2.1 Compliance Reference

### Level AA Requirements (Minimum for Production)

| Guideline                    | Success Criteria                      | Implementation                                                        |
| ---------------------------- | ------------------------------------- | --------------------------------------------------------------------- |
| 1.1.1 Non-text Content       | Alt text for images                   | `alt=""` for decorative, descriptive for informative                  |
| 1.3.1 Info and Relationships | Semantic HTML                         | Use `<header>`, `<nav>`, `<main>`, `<article>`, `<aside>`, `<footer>` |
| 1.3.2 Meaningful Sequence    | Logical DOM order                     | CSS positioning should not break reading order                        |
| 1.4.3 Contrast (Minimum)     | 4.5:1 text, 3:1 large text            | Use contrast checker tools                                            |
| 1.4.4 Resize Text            | 200% zoom support                     | Use relative units (rem, em)                                          |
| 1.4.10 Reflow                | No horizontal scroll at 320px         | Responsive design, no fixed widths                                    |
| 1.4.11 Non-text Contrast     | 3:1 for UI components                 | Borders, icons, focus indicators                                      |
| 2.1.1 Keyboard               | All functionality via keyboard        | No mouse-only interactions                                            |
| 2.1.2 No Keyboard Trap       | Escape from all components            | Focus trap with escape route                                          |
| 2.4.3 Focus Order            | Logical tab sequence                  | `tabindex="0"` for custom elements                                    |
| 2.4.6 Headings and Labels    | Descriptive headings                  | Proper heading hierarchy (h1-h6)                                      |
| 2.4.7 Focus Visible          | Visible focus indicator               | Never `outline: none` without replacement                             |
| 2.5.3 Label in Name          | Visible label matches accessible name | `aria-label` includes visible text                                    |
| 3.1.1 Language of Page       | `lang` attribute on `<html>`          | `<html lang="en">`                                                    |
| 3.2.1 On Focus               | No unexpected context changes         | No auto-submit, no popups on focus                                    |
| 4.1.2 Name, Role, Value      | Accessible name for controls          | Labels, ARIA attributes                                               |

### Level AAA Requirements (Enhanced Accessibility)

| Guideline                      | Success Criteria                | Implementation                    |
| ------------------------------ | ------------------------------- | --------------------------------- |
| 1.4.6 Contrast (Enhanced)      | 7:1 text, 4.5:1 large text      | Higher contrast color schemes     |
| 1.4.8 Visual Presentation      | User-controlled text settings   | Support for user stylesheets      |
| 2.2.3 No Timing                | No time limits                  | Remove or make adjustable         |
| 2.4.9 Link Purpose (Link Only) | Link text alone is descriptive  | Avoid "click here", "read more"   |
| 3.1.5 Reading Level            | Lower secondary education level | Simplified language option        |
| 3.2.5 Change on Request        | User-initiated changes only     | No auto-refresh, no auto-redirect |

---

## Comprehensive ARIA Patterns Library

### 1. Modal Dialog Pattern

```html
<!-- Trigger button -->
<button
  type="button"
  aria-haspopup="dialog"
  aria-expanded="false"
  data-dialog-trigger="confirm-dialog"
>
  Open Dialog
</button>

<!-- Modal dialog -->
<div
  id="confirm-dialog"
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-description"
  hidden
>
  <div class="dialog-overlay" data-dialog-close></div>
  <div class="dialog-content" role="document">
    <header>
      <h2 id="dialog-title">Confirm Action</h2>
      <button
        type="button"
        class="dialog-close"
        aria-label="Close dialog"
        data-dialog-close
      >
        <span aria-hidden="true">&times;</span>
      </button>
    </header>
    <div id="dialog-description">
      <p>Are you sure you want to proceed with this action?</p>
    </div>
    <footer>
      <button type="button" data-dialog-close>Cancel</button>
      <button type="button" class="primary" data-dialog-confirm>Confirm</button>
    </footer>
  </div>
</div>
```

```typescript
// Focus trap implementation for modal dialogs
class AccessibleDialog {
  private dialog: HTMLElement;
  private trigger: HTMLElement | null = null;
  private focusableElements: HTMLElement[] = [];
  private firstFocusable: HTMLElement | null = null;
  private lastFocusable: HTMLElement | null = null;

  constructor(dialogId: string) {
    this.dialog = document.getElementById(dialogId)!;
    this.init();
  }

  private init(): void {
    // Find all focusable elements
    const focusableSelectors = [
      "button:not([disabled])",
      "input:not([disabled])",
      "select:not([disabled])",
      "textarea:not([disabled])",
      "a[href]",
      '[tabindex]:not([tabindex="-1"])',
    ].join(", ");

    this.focusableElements = Array.from(
      this.dialog.querySelectorAll<HTMLElement>(focusableSelectors),
    );
    this.firstFocusable = this.focusableElements[0] || null;
    this.lastFocusable =
      this.focusableElements[this.focusableElements.length - 1] || null;
  }

  public open(trigger?: HTMLElement): void {
    this.trigger = trigger || (document.activeElement as HTMLElement);

    // Update trigger state
    if (this.trigger) {
      this.trigger.setAttribute("aria-expanded", "true");
    }

    // Show dialog
    this.dialog.hidden = false;
    this.dialog.setAttribute("aria-hidden", "false");
    document.body.classList.add("dialog-open");
    document.body.setAttribute("aria-hidden", "true");

    // Move focus to first focusable element
    this.firstFocusable?.focus();

    // Add event listeners
    this.dialog.addEventListener("keydown", this.handleKeyDown);
    document.addEventListener("click", this.handleOutsideClick);
  }

  public close(): void {
    // Hide dialog
    this.dialog.hidden = true;
    this.dialog.setAttribute("aria-hidden", "true");
    document.body.classList.remove("dialog-open");
    document.body.removeAttribute("aria-hidden");

    // Update trigger state
    if (this.trigger) {
      this.trigger.setAttribute("aria-expanded", "false");
      this.trigger.focus(); // Return focus to trigger
    }

    // Remove event listeners
    this.dialog.removeEventListener("keydown", this.handleKeyDown);
    document.removeEventListener("click", this.handleOutsideClick);
  }

  private handleKeyDown = (event: KeyboardEvent): void => {
    switch (event.key) {
      case "Escape":
        this.close();
        break;
      case "Tab":
        this.trapFocus(event);
        break;
    }
  };

  private trapFocus(event: KeyboardEvent): void {
    if (!this.firstFocusable || !this.lastFocusable) return;

    if (event.shiftKey) {
      // Shift + Tab: if on first element, move to last
      if (document.activeElement === this.firstFocusable) {
        event.preventDefault();
        this.lastFocusable.focus();
      }
    } else {
      // Tab: if on last element, move to first
      if (document.activeElement === this.lastFocusable) {
        event.preventDefault();
        this.firstFocusable.focus();
      }
    }
  }

  private handleOutsideClick = (event: MouseEvent): void => {
    const target = event.target as HTMLElement;
    if (target.hasAttribute("data-dialog-close")) {
      this.close();
    }
  };
}
```

### 2. Tabs Pattern (Manual Activation)

```html
<div class="tabs">
  <div role="tablist" aria-label="Product Information">
    <button
      role="tab"
      id="tab-description"
      aria-selected="true"
      aria-controls="panel-description"
      tabindex="0"
    >
      Description
    </button>
    <button
      role="tab"
      id="tab-specifications"
      aria-selected="false"
      aria-controls="panel-specifications"
      tabindex="-1"
    >
      Specifications
    </button>
    <button
      role="tab"
      id="tab-reviews"
      aria-selected="false"
      aria-controls="panel-reviews"
      tabindex="-1"
    >
      Reviews
    </button>
  </div>

  <div
    id="panel-description"
    role="tabpanel"
    aria-labelledby="tab-description"
    tabindex="0"
  >
    <h3>Product Description</h3>
    <p>Detailed product description content...</p>
  </div>

  <div
    id="panel-specifications"
    role="tabpanel"
    aria-labelledby="tab-specifications"
    tabindex="0"
    hidden
  >
    <h3>Technical Specifications</h3>
    <dl>
      <dt>Weight</dt>
      <dd>2.5 kg</dd>
      <dt>Dimensions</dt>
      <dd>30 x 20 x 10 cm</dd>
    </dl>
  </div>

  <div
    id="panel-reviews"
    role="tabpanel"
    aria-labelledby="tab-reviews"
    tabindex="0"
    hidden
  >
    <h3>Customer Reviews</h3>
    <p>Reviews content...</p>
  </div>
</div>
```

```typescript
// Accessible tabs with arrow key navigation
class AccessibleTabs {
  private tablist: HTMLElement;
  private tabs: HTMLElement[];
  private panels: HTMLElement[];
  private currentIndex: number = 0;

  constructor(container: HTMLElement) {
    this.tablist = container.querySelector('[role="tablist"]')!;
    this.tabs = Array.from(this.tablist.querySelectorAll('[role="tab"]'));
    this.panels = this.tabs.map(
      (tab) => document.getElementById(tab.getAttribute("aria-controls")!)!,
    );
    this.init();
  }

  private init(): void {
    this.tabs.forEach((tab, index) => {
      tab.addEventListener("click", () => this.selectTab(index));
      tab.addEventListener("keydown", (e) => this.handleKeyDown(e, index));
    });
  }

  private handleKeyDown(event: KeyboardEvent, index: number): void {
    const key = event.key;
    let newIndex = index;

    switch (key) {
      case "ArrowLeft":
      case "ArrowUp":
        newIndex = index === 0 ? this.tabs.length - 1 : index - 1;
        break;
      case "ArrowRight":
      case "ArrowDown":
        newIndex = index === this.tabs.length - 1 ? 0 : index + 1;
        break;
      case "Home":
        newIndex = 0;
        break;
      case "End":
        newIndex = this.tabs.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    this.tabs[newIndex].focus();
    // Optional: auto-activate on arrow key (remove for manual activation)
    // this.selectTab(newIndex);
  }

  private selectTab(index: number): void {
    // Deactivate all tabs
    this.tabs.forEach((tab, i) => {
      tab.setAttribute("aria-selected", "false");
      tab.setAttribute("tabindex", "-1");
      this.panels[i].hidden = true;
    });

    // Activate selected tab
    this.tabs[index].setAttribute("aria-selected", "true");
    this.tabs[index].setAttribute("tabindex", "0");
    this.panels[index].hidden = false;
    this.currentIndex = index;
  }
}
```

### 3. Accordion Pattern

```html
<div class="accordion" data-allow-multiple="false">
  <h3>
    <button
      type="button"
      aria-expanded="true"
      aria-controls="accordion-panel-1"
      id="accordion-header-1"
      class="accordion-trigger"
    >
      <span class="accordion-title">Section 1</span>
      <span class="accordion-icon" aria-hidden="true"></span>
    </button>
  </h3>
  <div
    id="accordion-panel-1"
    role="region"
    aria-labelledby="accordion-header-1"
    class="accordion-panel"
  >
    <p>Section 1 content goes here...</p>
  </div>

  <h3>
    <button
      type="button"
      aria-expanded="false"
      aria-controls="accordion-panel-2"
      id="accordion-header-2"
      class="accordion-trigger"
    >
      <span class="accordion-title">Section 2</span>
      <span class="accordion-icon" aria-hidden="true"></span>
    </button>
  </h3>
  <div
    id="accordion-panel-2"
    role="region"
    aria-labelledby="accordion-header-2"
    class="accordion-panel"
    hidden
  >
    <p>Section 2 content goes here...</p>
  </div>
</div>
```

### 4. Combobox with Autocomplete

```html
<div class="combobox-container">
  <label id="search-label" for="search-input"> Search products </label>
  <div class="combobox-wrapper">
    <input
      type="text"
      id="search-input"
      role="combobox"
      aria-autocomplete="list"
      aria-expanded="false"
      aria-controls="search-listbox"
      aria-activedescendant=""
      aria-describedby="search-instructions"
      autocomplete="off"
    />
    <button
      type="button"
      tabindex="-1"
      aria-label="Clear search"
      class="clear-button"
      hidden
    >
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
  <div id="search-instructions" class="visually-hidden">
    Use up and down arrows to navigate suggestions. Press Enter to select.
  </div>
  <ul id="search-listbox" role="listbox" aria-label="Search suggestions" hidden>
    <!-- Options populated dynamically -->
    <li role="option" id="option-1" aria-selected="false">Suggestion 1</li>
    <li role="option" id="option-2" aria-selected="false">Suggestion 2</li>
  </ul>
  <div aria-live="polite" aria-atomic="true" class="visually-hidden">
    <!-- Announcement for screen readers -->
  </div>
</div>
```

### 5. Menu Button Pattern

```html
<div class="menu-container">
  <button
    type="button"
    id="menu-button"
    aria-haspopup="true"
    aria-expanded="false"
    aria-controls="menu-list"
  >
    Actions
    <span aria-hidden="true" class="dropdown-arrow"></span>
  </button>
  <ul id="menu-list" role="menu" aria-labelledby="menu-button" hidden>
    <li role="none">
      <a role="menuitem" href="/edit" tabindex="-1"> Edit </a>
    </li>
    <li role="none">
      <button role="menuitem" type="button" tabindex="-1">Duplicate</button>
    </li>
    <li role="separator"></li>
    <li role="none">
      <button role="menuitem" type="button" tabindex="-1" class="danger">
        Delete
      </button>
    </li>
  </ul>
</div>
```

### 6. Live Regions for Dynamic Content

```html
<!-- Status messages (polite) -->
<div
  aria-live="polite"
  aria-atomic="true"
  class="status-announcer visually-hidden"
>
  <!-- Dynamically updated content -->
</div>

<!-- Urgent alerts (assertive) -->
<div
  role="alert"
  aria-live="assertive"
  aria-atomic="true"
  class="alert-announcer visually-hidden"
>
  <!-- Critical announcements -->
</div>

<!-- Progress updates -->
<div role="status" aria-live="polite" aria-label="Loading progress">
  <span class="visually-hidden">Loading: </span>
  <span id="progress-text">45%</span>
</div>

<!-- Log for chat/activity feeds -->
<div
  role="log"
  aria-live="polite"
  aria-relevant="additions"
  aria-label="Chat messages"
>
  <!-- New messages appended here -->
</div>
```

```typescript
// Live region announcer utility
class ScreenReaderAnnouncer {
  private politeRegion: HTMLElement;
  private assertiveRegion: HTMLElement;
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;

  constructor() {
    this.politeRegion = this.createRegion("polite");
    this.assertiveRegion = this.createRegion("assertive");
  }

  private createRegion(politeness: "polite" | "assertive"): HTMLElement {
    const region = document.createElement("div");
    region.setAttribute("aria-live", politeness);
    region.setAttribute("aria-atomic", "true");
    region.className = "visually-hidden";
    region.style.cssText = `
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    `;
    document.body.appendChild(region);
    return region;
  }

  public announce(
    message: string,
    priority: "polite" | "assertive" = "polite",
  ): void {
    const region =
      priority === "assertive" ? this.assertiveRegion : this.politeRegion;

    // Clear and reset to ensure announcement
    region.textContent = "";

    // Small delay to ensure the DOM change is detected
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      region.textContent = message;
    }, 100);
  }

  public announceFormError(fieldName: string, error: string): void {
    this.announce(`Error in ${fieldName}: ${error}`, "assertive");
  }

  public announceLoadingComplete(itemCount?: number): void {
    const message =
      itemCount !== undefined
        ? `Loading complete. ${itemCount} items loaded.`
        : "Loading complete.";
    this.announce(message);
  }
}

// Global instance
const announcer = new ScreenReaderAnnouncer();
export default announcer;
```

### 7. Data Table with Sorting

```html
<div role="region" aria-labelledby="table-caption" tabindex="0">
  <table>
    <caption id="table-caption">
      User accounts - sorted by name ascending
    </caption>
    <thead>
      <tr>
        <th scope="col" aria-sort="ascending">
          <button type="button" aria-label="Sort by name, currently ascending">
            Name
            <span aria-hidden="true" class="sort-indicator"></span>
          </button>
        </th>
        <th scope="col" aria-sort="none">
          <button type="button" aria-label="Sort by email">
            Email
            <span aria-hidden="true" class="sort-indicator"></span>
          </button>
        </th>
        <th scope="col" aria-sort="none">
          <button type="button" aria-label="Sort by role">
            Role
            <span aria-hidden="true" class="sort-indicator"></span>
          </button>
        </th>
        <th scope="col">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <th scope="row">Alice Johnson</th>
        <td>alice@example.com</td>
        <td>Administrator</td>
        <td>
          <button type="button" aria-label="Edit Alice Johnson">Edit</button>
          <button type="button" aria-label="Delete Alice Johnson">
            Delete
          </button>
        </td>
      </tr>
    </tbody>
  </table>
</div>
```

### 8. Skip Links Pattern

```html
<body>
  <!-- Skip links - first focusable elements -->
  <nav aria-label="Skip links" class="skip-links">
    <a href="#main-content" class="skip-link"> Skip to main content </a>
    <a href="#main-navigation" class="skip-link"> Skip to navigation </a>
    <a href="#search" class="skip-link"> Skip to search </a>
  </nav>

  <header>
    <nav id="main-navigation" aria-label="Main navigation">
      <!-- Navigation content -->
    </nav>
    <form id="search" role="search" aria-label="Site search">
      <!-- Search form -->
    </form>
  </header>

  <main id="main-content" tabindex="-1">
    <!-- Main content -->
  </main>
</body>

<style>
  .skip-links {
    position: absolute;
    top: 0;
    left: 0;
    z-index: 9999;
  }

  .skip-link {
    position: absolute;
    top: -40px;
    left: 0;
    padding: 8px 16px;
    background: #000;
    color: #fff;
    text-decoration: none;
    transition: top 0.2s;
  }

  .skip-link:focus {
    top: 0;
    outline: 2px solid #fff;
    outline-offset: 2px;
  }
</style>
```

---

## Keyboard Navigation Implementation

### Focus Management System

```typescript
// Comprehensive focus management utility
class FocusManager {
  private focusHistory: HTMLElement[] = [];
  private maxHistoryLength: number = 10;

  // Selector for all focusable elements
  private readonly FOCUSABLE_SELECTOR = [
    'a[href]:not([tabindex="-1"])',
    'button:not([disabled]):not([tabindex="-1"])',
    'input:not([disabled]):not([tabindex="-1"]):not([type="hidden"])',
    'select:not([disabled]):not([tabindex="-1"])',
    'textarea:not([disabled]):not([tabindex="-1"])',
    '[tabindex]:not([tabindex="-1"])',
    '[contenteditable="true"]',
    "audio[controls]",
    "video[controls]",
    "details > summary:first-of-type",
  ].join(", ");

  // Get all focusable elements within a container
  public getFocusableElements(
    container: HTMLElement = document.body,
  ): HTMLElement[] {
    const elements = Array.from(
      container.querySelectorAll<HTMLElement>(this.FOCUSABLE_SELECTOR),
    );

    // Filter out elements that are not visible or are within closed details
    return elements.filter((el) => {
      if (el.offsetParent === null && !el.closest("[hidden]")) {
        // Check if it's visually hidden but still focusable
        const style = window.getComputedStyle(el);
        return style.visibility !== "hidden" && style.display !== "none";
      }
      return el.offsetParent !== null;
    });
  }

  // Save current focus to history
  public saveFocus(): void {
    const activeElement = document.activeElement as HTMLElement;
    if (activeElement && activeElement !== document.body) {
      this.focusHistory.push(activeElement);
      if (this.focusHistory.length > this.maxHistoryLength) {
        this.focusHistory.shift();
      }
    }
  }

  // Restore focus to previously focused element
  public restoreFocus(): void {
    const previousElement = this.focusHistory.pop();
    if (previousElement && document.body.contains(previousElement)) {
      previousElement.focus();
    }
  }

  // Move focus to a specific element with scroll into view
  public moveFocus(
    element: HTMLElement,
    options: ScrollIntoViewOptions = {},
  ): void {
    this.saveFocus();
    element.focus({ preventScroll: true });
    element.scrollIntoView({
      behavior: "smooth",
      block: "nearest",
      ...options,
    });
  }

  // Create a focus trap within a container
  public createFocusTrap(container: HTMLElement): () => void {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Tab") return;

      const focusableElements = this.getFocusableElements(container);
      if (focusableElements.length === 0) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      if (event.shiftKey) {
        if (document.activeElement === firstElement) {
          event.preventDefault();
          lastElement.focus();
        }
      } else {
        if (document.activeElement === lastElement) {
          event.preventDefault();
          firstElement.focus();
        }
      }
    };

    container.addEventListener("keydown", handleKeyDown);

    // Return cleanup function
    return () => {
      container.removeEventListener("keydown", handleKeyDown);
    };
  }

  // Roving tabindex for lists/grids
  public setupRovingTabindex(
    container: HTMLElement,
    selector: string,
    orientation: "horizontal" | "vertical" | "both" = "vertical",
  ): void {
    const items = Array.from(container.querySelectorAll<HTMLElement>(selector));
    if (items.length === 0) return;

    // Set initial tabindex
    items.forEach((item, index) => {
      item.setAttribute("tabindex", index === 0 ? "0" : "-1");
    });

    const handleKeyDown = (event: KeyboardEvent) => {
      const currentIndex = items.indexOf(event.target as HTMLElement);
      if (currentIndex === -1) return;

      let newIndex = currentIndex;
      const isVertical = orientation === "vertical" || orientation === "both";
      const isHorizontal =
        orientation === "horizontal" || orientation === "both";

      switch (event.key) {
        case "ArrowUp":
          if (isVertical) {
            newIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1;
          }
          break;
        case "ArrowDown":
          if (isVertical) {
            newIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0;
          }
          break;
        case "ArrowLeft":
          if (isHorizontal) {
            newIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1;
          }
          break;
        case "ArrowRight":
          if (isHorizontal) {
            newIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0;
          }
          break;
        case "Home":
          newIndex = 0;
          break;
        case "End":
          newIndex = items.length - 1;
          break;
        default:
          return;
      }

      if (newIndex !== currentIndex) {
        event.preventDefault();
        items[currentIndex].setAttribute("tabindex", "-1");
        items[newIndex].setAttribute("tabindex", "0");
        items[newIndex].focus();
      }
    };

    container.addEventListener("keydown", handleKeyDown);
  }
}

export const focusManager = new FocusManager();
```

### Keyboard Shortcut Manager

```typescript
// Accessible keyboard shortcut system
interface KeyboardShortcut {
  key: string;
  modifiers?: ("ctrl" | "alt" | "shift" | "meta")[];
  action: () => void;
  description: string;
  scope?: string;
}

class KeyboardShortcutManager {
  private shortcuts: Map<string, KeyboardShortcut> = new Map();
  private enabled: boolean = true;

  public register(shortcut: KeyboardShortcut): void {
    const key = this.getShortcutKey(shortcut.key, shortcut.modifiers);
    this.shortcuts.set(key, shortcut);
  }

  public unregister(
    key: string,
    modifiers?: ("ctrl" | "alt" | "shift" | "meta")[],
  ): void {
    const shortcutKey = this.getShortcutKey(key, modifiers);
    this.shortcuts.delete(shortcutKey);
  }

  private getShortcutKey(key: string, modifiers?: string[]): string {
    const mods = modifiers ? modifiers.sort().join("+") : "";
    return mods ? `${mods}+${key.toLowerCase()}` : key.toLowerCase();
  }

  public init(): void {
    document.addEventListener("keydown", this.handleKeyDown.bind(this));
  }

  private handleKeyDown(event: KeyboardEvent): void {
    if (!this.enabled) return;

    // Don't trigger shortcuts when typing in inputs
    const target = event.target as HTMLElement;
    if (this.isEditableElement(target)) return;

    const modifiers: string[] = [];
    if (event.ctrlKey) modifiers.push("ctrl");
    if (event.altKey) modifiers.push("alt");
    if (event.shiftKey) modifiers.push("shift");
    if (event.metaKey) modifiers.push("meta");

    const key = this.getShortcutKey(event.key, modifiers);
    const shortcut = this.shortcuts.get(key);

    if (shortcut) {
      event.preventDefault();
      shortcut.action();
    }
  }

  private isEditableElement(element: HTMLElement): boolean {
    return (
      element.tagName === "INPUT" ||
      element.tagName === "TEXTAREA" ||
      element.tagName === "SELECT" ||
      element.isContentEditable
    );
  }

  // Generate help dialog content
  public getShortcutList(): KeyboardShortcut[] {
    return Array.from(this.shortcuts.values());
  }

  public enable(): void {
    this.enabled = true;
  }

  public disable(): void {
    this.enabled = false;
  }
}

export const shortcuts = new KeyboardShortcutManager();

// Example usage
shortcuts.register({
  key: "/",
  description: "Focus search",
  action: () => document.getElementById("search-input")?.focus(),
});

shortcuts.register({
  key: "k",
  modifiers: ["ctrl"],
  description: "Open command palette",
  action: () => {
    /* open command palette */
  },
});

shortcuts.register({
  key: "?",
  modifiers: ["shift"],
  description: "Show keyboard shortcuts",
  action: () => {
    /* show shortcuts dialog */
  },
});
```

---

## Color Contrast Checking

### Contrast Utilities

```typescript
// Color contrast calculation utilities
interface RGB {
  r: number;
  g: number;
  b: number;
}

interface ContrastResult {
  ratio: number;
  aa: { normal: boolean; large: boolean };
  aaa: { normal: boolean; large: boolean };
}

class ColorContrastChecker {
  // Convert hex to RGB
  private hexToRgb(hex: string): RGB | null {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result
      ? {
          r: parseInt(result[1], 16),
          g: parseInt(result[2], 16),
          b: parseInt(result[3], 16),
        }
      : null;
  }

  // Calculate relative luminance per WCAG 2.1
  private getRelativeLuminance(rgb: RGB): number {
    const [r, g, b] = [rgb.r, rgb.g, rgb.b].map((channel) => {
      const sRGB = channel / 255;
      return sRGB <= 0.03928
        ? sRGB / 12.92
        : Math.pow((sRGB + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  // Calculate contrast ratio
  public getContrastRatio(color1: string, color2: string): number {
    const rgb1 = this.hexToRgb(color1);
    const rgb2 = this.hexToRgb(color2);

    if (!rgb1 || !rgb2) {
      throw new Error("Invalid color format. Use hex colors (e.g., #ffffff)");
    }

    const l1 = this.getRelativeLuminance(rgb1);
    const l2 = this.getRelativeLuminance(rgb2);

    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  // Check WCAG compliance
  public checkCompliance(
    foreground: string,
    background: string,
  ): ContrastResult {
    const ratio = this.getContrastRatio(foreground, background);

    return {
      ratio: Math.round(ratio * 100) / 100,
      aa: {
        normal: ratio >= 4.5, // 4.5:1 for normal text
        large: ratio >= 3, // 3:1 for large text (18pt or 14pt bold)
      },
      aaa: {
        normal: ratio >= 7, // 7:1 for enhanced contrast
        large: ratio >= 4.5, // 4.5:1 for large text enhanced
      },
    };
  }

  // Suggest accessible color alternatives
  public suggestAccessibleColor(
    foreground: string,
    background: string,
    targetRatio: number = 4.5,
  ): string {
    const rgb = this.hexToRgb(foreground);
    if (!rgb) return foreground;

    const bgLuminance = this.getRelativeLuminance(this.hexToRgb(background)!);
    const fgLuminance = this.getRelativeLuminance(rgb);

    // Determine if we need to lighten or darken
    const needsDarker = fgLuminance > bgLuminance;

    let adjustedRgb = { ...rgb };
    let attempts = 0;
    const maxAttempts = 100;

    while (attempts < maxAttempts) {
      const currentRatio = this.getContrastRatio(
        this.rgbToHex(adjustedRgb),
        background,
      );

      if (currentRatio >= targetRatio) {
        return this.rgbToHex(adjustedRgb);
      }

      // Adjust color
      const adjustment = needsDarker ? -5 : 5;
      adjustedRgb = {
        r: Math.max(0, Math.min(255, adjustedRgb.r + adjustment)),
        g: Math.max(0, Math.min(255, adjustedRgb.g + adjustment)),
        b: Math.max(0, Math.min(255, adjustedRgb.b + adjustment)),
      };

      attempts++;
    }

    return this.rgbToHex(adjustedRgb);
  }

  private rgbToHex(rgb: RGB): string {
    const toHex = (n: number) => n.toString(16).padStart(2, "0");
    return `#${toHex(rgb.r)}${toHex(rgb.g)}${toHex(rgb.b)}`;
  }
}

export const contrastChecker = new ColorContrastChecker();
```

### CSS Custom Properties for Accessible Colors

```css
:root {
  /* Base colors with contrast ratios noted */
  --color-text-primary: #1a1a1a; /* 15.3:1 on white */
  --color-text-secondary: #4a4a4a; /* 7.4:1 on white */
  --color-text-muted: #6b6b6b; /* 4.5:1 on white (AA minimum) */
  --color-text-inverse: #ffffff; /* Use on dark backgrounds */

  /* Interactive colors - AA compliant */
  --color-link: #0052cc; /* 7.1:1 on white */
  --color-link-hover: #003d99; /* 9.5:1 on white */
  --color-link-visited: #5e4db2; /* 4.5:1 on white */

  /* Status colors - AA compliant */
  --color-success: #006644; /* 5.8:1 on white */
  --color-warning: #b45309; /* 4.5:1 on white */
  --color-error: #c41e3a; /* 5.2:1 on white */
  --color-info: #0052cc; /* 7.1:1 on white */

  /* Focus indicator */
  --color-focus: #0052cc;
  --focus-outline-width: 2px;
  --focus-outline-offset: 2px;

  /* High contrast mode overrides */
  @media (prefers-contrast: high) {
    --color-text-primary: #000000;
    --color-text-secondary: #1a1a1a;
    --color-link: #0000ee;
    --color-focus: #000000;
    --focus-outline-width: 3px;
  }
}

/* Dark mode colors */
@media (prefers-color-scheme: dark) {
  :root {
    --color-text-primary: #f0f0f0; /* 15.3:1 on #1a1a1a */
    --color-text-secondary: #b0b0b0; /* 7.4:1 on #1a1a1a */
    --color-text-muted: #909090; /* 4.5:1 on #1a1a1a */
    --color-link: #6b9eff; /* 7.1:1 on #1a1a1a */
    --color-focus: #6b9eff;

    --color-success: #4ade80;
    --color-warning: #fbbf24;
    --color-error: #f87171;
  }
}
```

---

## Accessibility Audit Checklist

### Pre-Launch Audit Template

```markdown
# Accessibility Audit Checklist - [Project Name]

**Date:** [YYYY-MM-DD]
**Auditor:** [Name]
**WCAG Target:** AA / AAA
**Scope:** [URLs or components audited]

## 1. Perceivable

### 1.1 Text Alternatives

- [ ] All images have alt text
- [ ] Decorative images use alt=""
- [ ] Complex images have long descriptions
- [ ] Form inputs have visible labels
- [ ] Icons have accessible names

### 1.2 Time-based Media

- [ ] Videos have captions
- [ ] Videos have audio descriptions (AAA)
- [ ] Audio has transcripts

### 1.3 Adaptable

- [ ] Semantic HTML structure
- [ ] Proper heading hierarchy (h1-h6)
- [ ] Reading order matches visual order
- [ ] Orientation not restricted

### 1.4 Distinguishable

- [ ] Color contrast meets 4.5:1 (text)
- [ ] Color contrast meets 3:1 (large text, UI)
- [ ] Information not conveyed by color alone
- [ ] Text resizes to 200% without loss
- [ ] No horizontal scroll at 320px width
- [ ] Text spacing adjustable without breaking
- [ ] Content on hover/focus dismissible

## 2. Operable

### 2.1 Keyboard Accessible

- [ ] All functionality via keyboard
- [ ] No keyboard traps
- [ ] Shortcuts can be turned off/remapped

### 2.2 Enough Time

- [ ] Time limits adjustable
- [ ] Moving content pausable
- [ ] No timing for essential actions

### 2.3 Seizures and Physical Reactions

- [ ] No flashing content (3 per second)
- [ ] Motion can be disabled

### 2.4 Navigable

- [ ] Skip links present
- [ ] Pages have descriptive titles
- [ ] Focus order logical
- [ ] Link purpose clear in context
- [ ] Multiple ways to find pages
- [ ] Focus indicator visible

### 2.5 Input Modalities

- [ ] Touch targets 44x44px minimum
- [ ] Pointer actions have alternatives
- [ ] Label in name matches visible label
- [ ] Motion actuation has alternatives

## 3. Understandable

### 3.1 Readable

- [ ] Page language specified
- [ ] Language of parts identified
- [ ] Unusual words defined (AAA)

### 3.2 Predictable

- [ ] No unexpected context changes
- [ ] Consistent navigation
- [ ] Consistent identification

### 3.3 Input Assistance

- [ ] Errors identified clearly
- [ ] Labels/instructions provided
- [ ] Error suggestions offered
- [ ] Error prevention for legal/financial

## 4. Robust

### 4.1 Compatible

- [ ] Valid HTML
- [ ] ARIA used correctly
- [ ] Status messages announced

## Automated Testing Results

### Tool: axe DevTools

- Critical: [ ] issues
- Serious: [ ] issues
- Moderate: [ ] issues
- Minor: [ ] issues

### Tool: WAVE

- Errors: [ ] issues
- Alerts: [ ] issues

### Tool: Lighthouse Accessibility

- Score: [ ]/100

## Manual Testing Results

### Screen Reader Testing

- [ ] NVDA (Windows)
- [ ] JAWS (Windows)
- [ ] VoiceOver (macOS)
- [ ] VoiceOver (iOS)
- [ ] TalkBack (Android)

### Keyboard-Only Navigation

- [ ] Can reach all interactive elements
- [ ] Focus visible at all times
- [ ] Can complete all tasks

### Zoom Testing

- [ ] 200% zoom works
- [ ] 400% zoom works (AAA)
- [ ] Text-only zoom works

## Issues Found

| ID  | WCAG  | Severity | Description       | Location      | Recommendation      |
| --- | ----- | -------- | ----------------- | ------------- | ------------------- |
| 1   | 1.1.1 | Critical | Missing alt text  | Homepage hero | Add descriptive alt |
| 2   | 2.4.7 | Serious  | Focus not visible | Dropdown      | Add focus styles    |

## Remediation Priority

### P0 - Critical (Block launch)

- [ ] Issue #X

### P1 - High (Fix within 1 week)

- [ ] Issue #X

### P2 - Medium (Fix within 1 month)

- [ ] Issue #X

### P3 - Low (Fix in next release)

- [ ] Issue #X

---

**Sign-off:**

- [ ] All P0/P1 issues resolved
- [ ] Accessibility statement published
- [ ] Ongoing monitoring in place
```

---

## Automated Testing Scripts

### axe-core Integration

```typescript
// Jest + axe-core accessibility testing
import { axe, toHaveNoViolations } from 'jest-axe';
import { render, RenderResult } from '@testing-library/react';

expect.extend(toHaveNoViolations);

// Generic accessibility test wrapper
export async function testAccessibility(
  ui: React.ReactElement,
  options?: Parameters<typeof axe>[1]
): Promise<void> {
  const { container } = render(ui);
  const results = await axe(container, {
    rules: {
      // Ensure color contrast is checked
      'color-contrast': { enabled: true },
      // Check for proper region landmarks
      'region': { enabled: true },
      // Verify labels on form elements
      'label': { enabled: true },
    },
    ...options
  });
  expect(results).toHaveNoViolations();
}

// Component-specific accessibility tests
describe('Button Component', () => {
  it('should have no accessibility violations', async () => {
    await testAccessibility(
      <Button onClick={() => {}}>Click me</Button>
    );
  });

  it('should have accessible name when icon-only', async () => {
    await testAccessibility(
      <Button onClick={() => {}} aria-label="Close dialog">
        <CloseIcon />
      </Button>
    );
  });

  it('should indicate disabled state', async () => {
    await testAccessibility(
      <Button disabled>Unavailable</Button>
    );
  });
});

// Full page accessibility tests
describe('Page Accessibility', () => {
  it('should have proper document structure', async () => {
    await testAccessibility(
      <Layout>
        <Header />
        <Main>
          <h1>Page Title</h1>
          <p>Content</p>
        </Main>
        <Footer />
      </Layout>,
      {
        rules: {
          'landmark-one-main': { enabled: true },
          'page-has-heading-one': { enabled: true },
          'bypass': { enabled: true }
        }
      }
    );
  });
});
```

### Playwright Accessibility Testing

```typescript
// Playwright accessibility testing with axe-core
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test.describe("Accessibility Tests", () => {
  test("homepage should have no critical accessibility issues", async ({
    page,
  }) => {
    await page.goto("/");

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();

    // Report violations
    if (results.violations.length > 0) {
      console.log(
        "Accessibility violations:",
        JSON.stringify(results.violations, null, 2),
      );
    }

    expect(results.violations).toHaveLength(0);
  });

  test("keyboard navigation should work correctly", async ({ page }) => {
    await page.goto("/");

    // Test skip link
    await page.keyboard.press("Tab");
    const skipLink = page.locator(".skip-link:focus");
    await expect(skipLink).toBeVisible();

    // Activate skip link
    await page.keyboard.press("Enter");
    const mainContent = page.locator("#main-content:focus");
    await expect(mainContent).toBeFocused();
  });

  test("modal should trap focus", async ({ page }) => {
    await page.goto("/modal-test");

    // Open modal
    await page.click("[data-dialog-trigger]");

    // Verify focus moved to modal
    const modalContent = page.locator('[role="dialog"]');
    await expect(modalContent).toBeVisible();

    // Tab through all focusable elements
    const focusableInModal = await modalContent
      .locator(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
      )
      .count();

    for (let i = 0; i < focusableInModal + 1; i++) {
      await page.keyboard.press("Tab");
    }

    // Focus should still be in modal (trapped)
    const activeElement = await page.evaluate(() =>
      document.activeElement?.closest('[role="dialog"]'),
    );
    expect(activeElement).not.toBeNull();
  });

  test("form should announce errors to screen readers", async ({ page }) => {
    await page.goto("/contact");

    // Submit empty form
    await page.click('button[type="submit"]');

    // Check for aria-invalid
    const invalidInputs = await page.locator('[aria-invalid="true"]').count();
    expect(invalidInputs).toBeGreaterThan(0);

    // Check for error messages with aria-describedby
    const errorMessages = await page
      .locator('[role="alert"], [aria-live="assertive"]')
      .count();
    expect(errorMessages).toBeGreaterThan(0);
  });
});

// Contrast testing
test("color contrast should meet WCAG AA", async ({ page }) => {
  await page.goto("/");

  const results = await new AxeBuilder({ page })
    .withRules(["color-contrast"])
    .analyze();

  expect(results.violations).toHaveLength(0);
});

// Generate accessibility report
test("generate full accessibility report", async ({ page }, testInfo) => {
  await page.goto("/");

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa", "best-practice"])
    .analyze();

  // Attach report to test results
  await testInfo.attach("accessibility-report", {
    body: JSON.stringify(results, null, 2),
    contentType: "application/json",
  });

  // Only fail on serious/critical
  const criticalViolations = results.violations.filter(
    (v) => v.impact === "critical" || v.impact === "serious",
  );

  expect(criticalViolations).toHaveLength(0);
});
```

### CI/CD Integration Script

```bash
#!/bin/bash
# /scripts/accessibility-audit.sh
# Automated accessibility audit for CI/CD pipeline

set -e

echo "=== Accessibility Audit ==="
echo "Date: $(date)"
echo "Target: ${TARGET_URL:-http://localhost:3000}"
echo ""

# Install dependencies if needed
if ! command -v pa11y &> /dev/null; then
    npm install -g pa11y pa11y-ci
fi

if ! command -v axe &> /dev/null; then
    npm install -g @axe-core/cli
fi

# Create reports directory
REPORT_DIR="./reports/accessibility"
mkdir -p "$REPORT_DIR"

# Run pa11y tests
echo "Running pa11y tests..."
pa11y-ci \
    --config .pa11yci.json \
    --reporter json \
    > "$REPORT_DIR/pa11y-results.json" 2>&1 || true

# Run axe-core tests
echo "Running axe-core tests..."
npx axe "${TARGET_URL:-http://localhost:3000}" \
    --tags wcag2a,wcag2aa,wcag21aa \
    --save "$REPORT_DIR/axe-results.json" || true

# Run Lighthouse accessibility audit
echo "Running Lighthouse accessibility audit..."
npx lighthouse "${TARGET_URL:-http://localhost:3000}" \
    --only-categories=accessibility \
    --output=json \
    --output-path="$REPORT_DIR/lighthouse-accessibility.json" \
    --chrome-flags="--headless --no-sandbox" || true

# Parse results and determine exit code
echo ""
echo "=== Results Summary ==="

# Count pa11y issues
PA11Y_ERRORS=$(jq 'map(.issues | length) | add // 0' "$REPORT_DIR/pa11y-results.json" 2>/dev/null || echo "0")
echo "pa11y errors: $PA11Y_ERRORS"

# Count axe violations
AXE_VIOLATIONS=$(jq '.violations | length' "$REPORT_DIR/axe-results.json" 2>/dev/null || echo "0")
echo "axe violations: $AXE_VIOLATIONS"

# Get Lighthouse score
LIGHTHOUSE_SCORE=$(jq '.categories.accessibility.score * 100' "$REPORT_DIR/lighthouse-accessibility.json" 2>/dev/null || echo "0")
echo "Lighthouse score: $LIGHTHOUSE_SCORE"

# Determine pass/fail
THRESHOLD=${ACCESSIBILITY_THRESHOLD:-90}
MAX_VIOLATIONS=${MAX_ACCESSIBILITY_VIOLATIONS:-0}

if [ "$LIGHTHOUSE_SCORE" -lt "$THRESHOLD" ] || [ "$AXE_VIOLATIONS" -gt "$MAX_VIOLATIONS" ]; then
    echo ""
    echo "FAIL: Accessibility requirements not met"
    echo "Required Lighthouse score: $THRESHOLD (got: $LIGHTHOUSE_SCORE)"
    echo "Max allowed violations: $MAX_VIOLATIONS (got: $AXE_VIOLATIONS)"
    exit 1
fi

echo ""
echo "PASS: Accessibility requirements met"
exit 0
```

### pa11y Configuration

```json
{
  "defaults": {
    "timeout": 30000,
    "wait": 1000,
    "standard": "WCAG2AA",
    "runners": ["axe", "htmlcs"],
    "chromeLaunchConfig": {
      "args": ["--no-sandbox", "--disable-setuid-sandbox"]
    }
  },
  "urls": [
    {
      "url": "http://localhost:3000",
      "screenCapture": "./reports/screenshots/home.png"
    },
    {
      "url": "http://localhost:3000/contact",
      "actions": ["wait for element #contact-form to be visible"]
    },
    {
      "url": "http://localhost:3000/login",
      "actions": [
        "set field #email to test@example.com",
        "click element button[type=submit]",
        "wait for element .error-message to be visible"
      ]
    }
  ]
}
```

---

## Screen Reader Testing Guide

### Testing Checklist by Screen Reader

```markdown
## VoiceOver (macOS/iOS)

### Setup

- Enable: System Preferences > Accessibility > VoiceOver
- Shortcut: Cmd + F5
- Rotor: VO + U

### Test Cases

- [ ] Page title announced on load
- [ ] Landmarks navigable via Rotor
- [ ] Headings navigable via Rotor
- [ ] Links list accessible
- [ ] Forms navigable
- [ ] Tables announced correctly
- [ ] Images described appropriately
- [ ] Live regions announced

### Common Commands

- VO + Right/Left: Navigate
- VO + Space: Activate
- VO + Shift + Down: Enter group
- VO + Shift + Up: Exit group
- VO + U: Open Rotor

---

## NVDA (Windows)

### Setup

- Download: nvaccess.org
- Toggle: Insert + Q

### Test Cases

- [ ] Browse mode works (automatic)
- [ ] Focus mode for forms
- [ ] Landmark navigation (D key)
- [ ] Heading navigation (H key)
- [ ] Table navigation (T key)
- [ ] Form fields labeled
- [ ] Buttons announced
- [ ] Links distinguish visited

### Common Commands

- Down/Up: Read next/previous
- Tab: Next focusable
- H: Next heading
- D: Next landmark
- T: Next table
- Insert + F7: Elements list

---

## JAWS (Windows)

### Setup

- Commercial license required
- Toggle: Insert + Z (virtual cursor)

### Test Cases

- [ ] Virtual cursor navigation
- [ ] Forms mode switching
- [ ] PlaceMarkers work
- [ ] Skim reading mode
- [ ] Research It feature
- [ ] Touch gestures (if applicable)

### Common Commands

- Arrow keys: Navigate
- Insert + F6: Heading list
- Insert + F7: Links list
- Enter: Activate/Forms mode
- Num Pad Plus: Forms mode off

---

## TalkBack (Android)

### Setup

- Settings > Accessibility > TalkBack

### Test Cases

- [ ] Touch exploration works
- [ ] Gestures registered
- [ ] Focus order correct
- [ ] Custom actions available
- [ ] Reading controls work

### Common Gestures

- Swipe right/left: Next/previous
- Double tap: Activate
- Swipe up then right: Next heading
- Two finger scroll: Scroll page
```

---

## Integration with Frontend Developer Agent

```markdown
## Coordination Protocol

When working with `/agents/frontend/frontend-developer`:

### 1. Early Integration

- Review designs BEFORE implementation begins
- Provide ARIA pattern recommendations upfront
- Flag potential contrast issues in mockups

### 2. Component Review

Request accessibility review for:

- Custom interactive components
- Form implementations
- Modal/dialog components
- Navigation structures
- Dynamic content areas

### 3. Handoff Format
```

ACCESSIBILITY REVIEW REQUEST:

- Component: [Name]
- Framework: [React/Vue/etc]
- Interactions: [Click, hover, keyboard]
- States: [Loading, error, empty, populated]
- Dependencies: [ARIA patterns needed]

```

### 4. Response Format
```

ACCESSIBILITY IMPLEMENTATION:

- ARIA Pattern: [Pattern name and code]
- Keyboard: [Navigation requirements]
- Focus: [Management approach]
- Announcements: [Live region usage]
- Testing: [Required test cases]

```

### 5. Verification
Before marking complete:
- [ ] Automated tests pass (axe, pa11y)
- [ ] Manual keyboard test complete
- [ ] Screen reader tested (minimum 1)
- [ ] Color contrast verified
- [ ] Focus management verified
```

---

## Common Anti-Patterns to Avoid

| Anti-Pattern                | Issue                      | Correct Approach                                                      |
| --------------------------- | -------------------------- | --------------------------------------------------------------------- |
| `<div onclick>`             | Not keyboard accessible    | Use `<button>` or add `role="button"` + `tabindex="0"` + key handlers |
| `outline: none`             | Removes focus indicator    | Replace with custom `:focus-visible` styles                           |
| `<a href="#">`              | No semantic meaning        | Use `<button>` for actions, real URLs for links                       |
| Placeholder as label        | Disappears on input        | Use visible `<label>` element                                         |
| `aria-label` on everything  | Overrides visible text     | Only use when no visible text exists                                  |
| Color-only indicators       | Fails for colorblind users | Add text, icons, or patterns                                          |
| Auto-playing media          | Disruptive                 | Require user action to play                                           |
| Infinite scroll only        | No keyboard access         | Add pagination alternative                                            |
| `tabindex > 0`              | Breaks natural order       | Use `tabindex="0"` or `-1` only                                       |
| Nested interactive elements | Invalid HTML               | Restructure to avoid nesting                                          |

---

## Quick Reference Card

### ARIA Quick Reference

| Use Case           | ARIA Attributes                     |
| ------------------ | ----------------------------------- |
| Label element      | `aria-label`, `aria-labelledby`     |
| Describe element   | `aria-describedby`                  |
| Hide from AT       | `aria-hidden="true"`                |
| Expanded/collapsed | `aria-expanded`                     |
| Selected state     | `aria-selected`                     |
| Checked state      | `aria-checked`                      |
| Disabled state     | `aria-disabled`                     |
| Loading state      | `aria-busy`                         |
| Error state        | `aria-invalid`, `aria-errormessage` |
| Current page       | `aria-current="page"`               |
| Live updates       | `aria-live`, `role="status"`        |
| Required field     | `aria-required`                     |

### Landmark Roles

| Landmark      | HTML Element | ARIA Role              |
| ------------- | ------------ | ---------------------- |
| Banner        | `<header>`   | `role="banner"`        |
| Navigation    | `<nav>`      | `role="navigation"`    |
| Main          | `<main>`     | `role="main"`          |
| Complementary | `<aside>`    | `role="complementary"` |
| Content Info  | `<footer>`   | `role="contentinfo"`   |
| Search        | -            | `role="search"`        |
| Form          | `<form>`     | `role="form"`          |
| Region        | `<section>`  | `role="region"`        |

---

## Examples

```bash
# Full page accessibility audit
/agents/frontend/accessibility-expert audit homepage for WCAG 2.1 AA compliance

# Implement accessible modal
/agents/frontend/accessibility-expert create accessible modal dialog with focus trap

# Fix keyboard navigation
/agents/frontend/accessibility-expert fix keyboard navigation in dropdown menu component

# Color contrast review
/agents/frontend/accessibility-expert check color contrast ratios for design system

# Screen reader optimization
/agents/frontend/accessibility-expert optimize product cards for VoiceOver

# Form accessibility
/agents/frontend/accessibility-expert implement accessible form with error handling

# Generate audit report
/agents/frontend/accessibility-expert generate accessibility audit report for checkout flow
```

---

**Author:** Ahmed Adel Bakr Alderai
