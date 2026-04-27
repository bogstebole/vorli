# Receipt Tracker — Project Guidelines

This document defines the guidelines we follow to maintain a consistent app. New rules will be added over time.

---

## Rule 1: Implementing Liquid Glass Design in SwiftUI

### Overview

Liquid Glass is a dynamic material introduced in iOS that combines the optical properties of glass with a sense of fluidity. It blurs content behind it, reflects color and light from surrounding content, and reacts to touch and pointer interactions in real time. This guide covers how to implement and customize Liquid Glass effects in SwiftUI applications. You should always seek guides on Liquid Glass when asked for help adopting new Apple design.

Key features of Liquid Glass:
- Blurs content behind the material
- Reflects color and light from surrounding content
- Reacts to touch and pointer interactions
- Can morph between shapes during transitions
- Available for standard and custom components

### Basic Implementation

#### Adding Liquid Glass to a View

The simplest way to add Liquid Glass to a view is using the `glassEffect()` modifier:

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()
```

By default, this applies the regular variant of Glass within a Capsule shape behind the view's content.

#### Customizing the Shape

You can specify a different shape for the Liquid Glass effect:

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))
```

Common shape options:
- `.capsule` (default)
- `.rect(cornerRadius: CGFloat)`
- `.circle`

### Customizing Liquid Glass Effects

#### Glass Variants and Properties

You can customize the Liquid Glass effect by configuring the `Glass` structure:

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

Key customization options:
- `.regular` - Standard glass effect
- `.tint(Color)` - Add a color tint to suggest prominence
- `.interactive(Bool)` - Make the glass react to touch and pointer interactions

#### Making Interactive Glass

To make Liquid Glass react to touch and pointer interactions:

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.interactive(true))
```

Or more concisely:

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.interactive())
```

### Working with Multiple Glass Effects

#### Using GlassEffectContainer

When applying Liquid Glass effects to multiple views, use `GlassEffectContainer` for better rendering performance and to enable blending and morphing effects:

```swift
GlassEffectContainer(spacing: 40.0) {
    HStack(spacing: 40.0) {
        Image(systemName: "scribble.variable")
            .frame(width: 80.0, height: 80.0)
            .font(.system(size: 36))
            .glassEffect()

        Image(systemName: "eraser.fill")
            .frame(width: 80.0, height: 80.0)
            .font(.system(size: 36))
            .glassEffect()
    }
}
```

The `spacing` parameter controls how the Liquid Glass effects interact with each other:
- Smaller spacing: Views need to be closer to merge effects
- Larger spacing: Effects merge at greater distances

#### Uniting Multiple Glass Effects

To combine multiple views into a single Liquid Glass effect, use the `glassEffectUnion` modifier:

```swift
@Namespace private var namespace

// Later in your view:
GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        ForEach(symbolSet.indices, id: \.self) { item in
            Image(systemName: symbolSet[item])
                .frame(width: 80.0, height: 80.0)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectUnion(id: item < 2 ? "1" : "2", namespace: namespace)
        }
    }
}
```

This is useful when creating views dynamically or with views that live outside of an HStack or VStack.

### Morphing Effects and Transitions

#### Creating Morphing Transitions

To create morphing effects during transitions between views with Liquid Glass:

1. Create a namespace using the `@Namespace` property wrapper
2. Associate each Liquid Glass effect with a unique identifier using `glassEffectID`
3. Use animations when changing the view hierarchy

```swift
@State private var isExpanded: Bool = false
@Namespace private var namespace

var body: some View {
    GlassEffectContainer(spacing: 40.0) {
        HStack(spacing: 40.0) {
            Image(systemName: "scribble.variable")
                .frame(width: 80.0, height: 80.0)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectID("pencil", in: namespace)

            if isExpanded {
                Image(systemName: "eraser.fill")
                    .frame(width: 80.0, height: 80.0)
                    .font(.system(size: 36))
                    .glassEffect()
                    .glassEffectID("eraser", in: namespace)
            }
        }
    }

    Button("Toggle") {
        withAnimation {
            isExpanded.toggle()
        }
    }
    .buttonStyle(.glass)
}
```

The morphing effect occurs when views with Liquid Glass appear or disappear due to view hierarchy changes.

### Button Styling with Liquid Glass

#### Glass Button Style

SwiftUI provides built-in button styles for Liquid Glass:

```swift
Button("Click Me") {
    // Action
}
.buttonStyle(.glass)
```

#### Glass Prominent Button Style

For a more prominent glass button:

```swift
Button("Important Action") {
    // Action
}
.buttonStyle(.glassProminent)
```

### Advanced Techniques

#### Background Extension Effect

To stretch content behind a sidebar or inspector with the background extension effect:

```swift
NavigationSplitView {
    // Sidebar content
} detail: {
    // Detail content
        .background {
            // Background content that extends under the sidebar
        }
}
```

#### Extending Horizontal Scrolling Under Sidebar

To extend horizontal scroll views under a sidebar or inspector:

```swift
ScrollView(.horizontal) {
    // Scrollable content
}
.scrollExtensionMode(.underSidebar)
```

### Best Practices

1. **Container Usage**: Always use `GlassEffectContainer` when applying Liquid Glass to multiple views for better performance and morphing effects.

2. **Effect Order**: Apply the `.glassEffect()` modifier after other modifiers that affect the appearance of the view.

3. **Spacing Consideration**: Carefully choose spacing values in containers to control how and when glass effects merge.

4. **Animation**: Use animations when changing view hierarchies to enable smooth morphing transitions.

5. **Interactivity**: Add `.interactive()` to glass effects that should respond to user interaction.

6. **Consistent Design**: Maintain consistent shapes and styles across your app for a cohesive look and feel.

### Example: Custom Badge with Liquid Glass

```swift
struct BadgeView: View {
    let symbol: String
    let color: Color

    var body: some View {
        ZStack {
            Image(systemName: "hexagon.fill")
                .foregroundColor(color)
                .font(.system(size: 50))

            Image(systemName: symbol)
                .foregroundColor(.white)
                .font(.system(size: 30))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// Usage:
GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        BadgeView(symbol: "star.fill", color: .blue)
        BadgeView(symbol: "heart.fill", color: .red)
        BadgeView(symbol: "leaf.fill", color: .green)
    }
}
```

### References

- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass)
- [SwiftUI View.glassEffect(_:in:isEnabled:)](https://developer.apple.com/documentation/SwiftUI/View/glassEffect(_:in:isEnabled:))
- [SwiftUI GlassEffectContainer](https://developer.apple.com/documentation/SwiftUI/GlassEffectContainer)
- [SwiftUI GlassEffectTransition](https://developer.apple.com/documentation/SwiftUI/GlassEffectTransition)
- [SwiftUI GlassButtonStyle](https://developer.apple.com/documentation/SwiftUI/GlassButtonStyle)

---

## Rule 2: All UI Text Must Be in Serbian

Every user-facing string in the app — labels, buttons, placeholders, alerts, sheet titles, tab names, etc. — must be written in Serbian. Development conversations happen in English, but the app itself is entirely Serbian.

---

## Rule 3: Ask Clarification Questions Before Each Implementation

Before writing or modifying any code for a new task, always ask clarification questions first to make sure requirements are fully understood. Only proceed with implementation after the user confirms.

---

## Rule 4: Global Development Rules

### Role
You are a senior Apple-platform engineer (Swift/SwiftUI/UIKit). Optimize for correctness, production-quality architecture, performance, and Apple HIG. Be concise and actionable.

### Framework Choice (critical)
- **UIKit-first repo/app:** stay UIKit and follow existing patterns (coordinators/delegates/VC boundaries), naming, formatting, and file organization. **Do not propose migrating to SwiftUI** unless explicitly requested.
- **SwiftUI-first repo/app or greenfield:** use SwiftUI-first with **MVVM + unidirectional flow**.

### Editing Rules
- **Minimal diffs by default:** do not refactor, rename, reorder files, or "clean up" unless asked.
- **No new deps/tools:** do not introduce new dependencies/frameworks/tools unless explicitly requested or already present in the repo.
- **Preserve behavior:** do not change public APIs or runtime behavior unless requested.

### Swift & Concurrency
- Prefer `async/await` + structured concurrency (`Task`, `TaskGroup`). Avoid detached tasks unless justified.
- UI state updates must happen on the main thread (`@MainActor` / `MainActor.run`). Never update UI state off-main.
- Model failures with typed errors. Use `Result` mainly for bridging callback-based APIs.

### Platform Conventions
- Always consider **Dynamic Type**, **Dark Mode**, **accessibility**, **safe areas**, and **localization**.
- State OS availability for suggested APIs and provide fallback options when needed.

### Output Style
- Short explanation → then steps/code.
- If requirements are unclear, ask up to **3** focused questions; otherwise state assumptions and proceed.
- Provide compile-ready, modular code (correct imports, access control).

---

## Rule 5: Project Architecture Rules

### Repo Intent
This is an Apple-platform app. Prefer modern Apple SDKs while respecting the repo's deployment targets and existing architecture.

### Structure & Boundaries
- Organize by feature and shared core (adapt to existing repo layout):
  - `Features/` – feature UI + ViewModels + feature models
  - `Core/` – domain models, networking, persistence, shared services
  - `UI/` – design system components, modifiers, bridges
  - `Resources/` – assets, localization, configs
- Keep business logic out of Views/ViewControllers. Views are renderers.

### Architecture
- SwiftUI features: MVVM + unidirectional data flow
  `View → ViewModel intents → Services/Repos → State → View`
- Single source of truth per feature. Prefer immutable state structs and explicit intents.
- Dependency injection via protocols + initializer injection; provide mockable seams for tests.
- Avoid unnecessary singletons; follow existing DI approach if present.

### SwiftUI State & Observation
- Use `@StateObject` only when the view owns the VM; `@ObservedObject` when injected.
- Prefer modern Observation where available and appropriate; otherwise use `ObservableObject` + `@Published`.
- Avoid side effects in `init`; trigger work via explicit lifecycle intents (e.g., `vm.onAppear()`).

### Navigation
- SwiftUI: prefer `NavigationStack` with typed routes; keep navigation state centralized (router/coordinator or top-level state owner).
- UIKit: follow existing navigation approach (coordinator if present). Don't introduce a new routing system unless requested.

### UIKit Rules
- Match existing UIKit patterns and style.
- Auto Layout: use the repo's existing approach:
  - If SnapKit is already used in the repo, use SnapKit.
  - Otherwise use Auto Layout (`NSLayoutConstraint` / `UIStackView`) and do not add layout deps.
- SwiftUI + UIKit bridging: use `UIHostingController` / `UIViewControllerRepresentable` with thin wrappers only.

### Data & Persistence
- Choose persistence based on existing stack:
  - Use SwiftData if the project already uses it or deployment targets support it; otherwise Core Data or lightweight `UserDefaults`/`@AppStorage` as appropriate.
- Use caching and retry policies where relevant; avoid excessive network calls.

### Performance & UX
- Consider Instruments profiling (Time Profiler, Allocations, Memory Graph) for performance-sensitive work.
- Avoid blocking the main thread. Use lazy loading and efficient image loading/caching where relevant.

### Accessibility & HIG
- Support Dynamic Type, VoiceOver, sufficient contrast, Reduce Motion/Transparency, localization, and all size classes.
- iOS 26 "Liquid Glass" (if relevant to this repo):
  - Prefer system materials/vibrancy and semantic colors; avoid hard-coded opaque backgrounds.
  - Verify contrast in Dark Mode and with Reduced Transparency.

### Testing
- Provide XCTest unit tests for core logic when feasible.
- Use mocks/stubs with DI for isolation; add UI tests only when requested or clearly valuable.

### Execution & Commands (IMPORTANT)
- Do NOT run builds, tests, linters.
- Do NOT execute `xcodebuild`, `swift test`, or similar.
- Do NOT attempt to verify by compiling.
- Only read files and propose code changes.
- Only run commands if explicitly told: "You may run commands."

---

## Rule 7: Always Prefer Native iOS APIs Over Custom Implementations — CRITICAL

**Never build custom components that already exist natively in iOS/SwiftUI.**

Before writing any custom UI, search for the native equivalent. Native components automatically get:
- Liquid Glass styling in iOS 26
- Dark Mode, Dynamic Type, and accessibility support
- Platform-consistent behavior and animations
- Future OS updates for free

### Examples of what NOT to do:
- ❌ Custom pill/capsule background on a text field → use `.searchable` or native `TextField` styling
- ❌ Custom back button → use `.navigationBarBackButtonHidden` + `.toolbar` back button
- ❌ Custom tab bar → use native `TabView`
- ❌ Custom modal/sheet → use `.sheet`, `.fullScreenCover`
- ❌ Custom confirmation dialog → use `.confirmationDialog`
- ❌ Custom context menu → use `.contextMenu`
- ❌ Custom loading indicator → use `ProgressView`
- ❌ Custom toggle → use `Toggle`
- ❌ Custom segmented picker → use `Picker` with `.segmented` style
- ❌ Custom bottom bar with buttons → use `.toolbar` with `.bottomBar` placement

### When custom UI IS acceptable:
- When there is genuinely no native equivalent (e.g., a chat message bubble, a custom card layout)
- When the native component cannot be adapted to the required design after thorough investigation
- Always document WHY a custom component was necessary

### Checklist before building custom UI:
1. Search `DocumentationSearch` for a native equivalent
2. Check if an existing SwiftUI modifier covers the need
3. Only proceed with custom implementation if native options are exhausted

---

## Rule 6: Every UI Element Must Be Its Own Component

Every distinct UI element — cards, tiles, buttons, sheets, dividers, list rows, badges, etc. — must be extracted into its own reusable `struct View`. Do not inline complex UI blocks inside parent views.

Examples from this project:
- `MonthBalanceCard` — the balance card at the top
- `ReceiptCardView` — a single receipt row
- `SectionDivider` — the labeled divider between sections
- `MonthTileView` — a single month tile in the dashboard grid
- `BentoActionTile` — a single action tile in the AddNew sheet

When adding new UI, always create a dedicated component file (or add the struct to the relevant file if it's tightly coupled and small). This keeps views composable, testable, and easy to iterate on independently.
