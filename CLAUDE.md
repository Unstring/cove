# Morfeo — Development Guidelines

## What is Morfeo

Morfeo is a GUI database client written in Swift + SwiftUI for macOS 15+.

## Code Style
- Idiomatic Swift 6. Structured concurrency, @Observable, modern SwiftUI APIs.
- Keep it simple. No premature abstractions, no unnecessary generics.
- Only add code that is needed right now.

## Structure
- One concern per file. Split files beyond ~300 lines.
- Organize by feature, not by layer.
- Only comment "why", never "what".

## Architecture

```
Morfeo/
  MorfeoApp.swift
  DB/
    DatabaseBackend.swift      — protocol all backends implement
    ConnectionConfig.swift     — connection configuration types
    HierarchyNode.swift        — tree hierarchy types
    QueryResult.swift          — query result types
    DbError.swift              — error types
    README.md                  — contributor guide for adding backends
    Postgres/                  — everything Postgres-specific
      PostgresBackend.swift    — class definition, connection pool
      PostgresHierarchy.swift  — tree navigation, node details
      PostgresDataOps.swift    — data fetching, query execution
      PostgresSQLGen.swift     — SQL generation
      PostgresDecoders.swift   — binary wire format decoders
  Views/                       — all SwiftUI views
  State/                       — @Observable state classes
  Store/                       — JSON persistence
  Theme/                       — color palette constants
```

- Each database backend lives in its own subdirectory under `DB/`.
- All backend-specific code (driver, SQL highlights, formatters, type mappings) goes inside that subdirectory.
- Shared DB abstractions (`DatabaseBackend` protocol, `QueryResult`, `HierarchyNode`, etc.) stay in `DB/` root.
- Adding a new database backend should require ZERO changes to UI code.

## UI Style
- Always use native macOS controls and materials. No custom-drawn buttons, backgrounds, or chrome when SwiftUI provides a standard equivalent.
- Use system button styles (`.bordered`, `.borderless`, `.borderedProminent`), native `Picker` with `.segmented`, and standard materials (`.bar`, `.ultraThinMaterial`) instead of custom colors/shapes.
- Prefer `.secondary` / `.primary` foreground styles over theme-specific colors for standard UI elements.
- Never implement custom gestures (e.g. `DragGesture`) for behaviors that SwiftUI or AppKit already provide. Use `HSplitView`/`VSplitView` for resizable panes, `NavigationSplitView` for navigation columns, native `List` for selection, etc. Custom gesture-based layout is always laggy compared to the system implementation.

## Error Handling
- Use `throws` and `try`. No force-unwraps in production code.
- String-based errors are fine when only displayed to the user.
- Only validate at system boundaries (user input, database responses).

## Dependencies
- Minimal. Every new package must justify its existence.
- Prefer Foundation/SwiftUI when good enough.

## Build & Run

```
xcodebuild -scheme Morfeo -derivedDataPath .build build && open .build/Build/Products/Debug/Morfeo.app
```

Or open `Morfeo.xcodeproj` in Xcode and build (Cmd+B).

## Tech Stack
- Swift 6 + SwiftUI (macOS 15+)
- PostgresNIO (PostgreSQL driver)
- SF Symbols (icons)
- @Observable (state management)
- JSON + Codable (persistence)
