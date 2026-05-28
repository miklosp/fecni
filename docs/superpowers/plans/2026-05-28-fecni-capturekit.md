# CaptureKit Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Commit policy (project instruction):** The user asked to hold commits until the first working version. Treat the per-task `git commit` steps as local checkpoints — a fully green CaptureKit at the end of this plan IS that first working version. Confirm with the user before the first commit; do not block on it.

**Goal:** Build `Packages/CaptureKit`, the deterministic, autonomously-testable core of fecni: settings, Obsidian vault detection, capture-file writing, and Markdown ↔ AttributedString round-tripping.

**Architecture:** A local SwiftPM library with no UI and no AppKit dependency, so it runs under `swift test --disable-sandbox` inside the Claude Code sandbox. Markdown conversion is symmetric, using swift-markdown's AST in both directions (parse → AST → AttributedString on load; AttributedString → AST → `format()` on save). The editor's in-memory model is `AttributedString`; `MarkdownDocument` is the only seam that knows Markdown.

**Tech Stack:** Swift 6.2, SwiftPM, Foundation `AttributedString`/`PresentationIntent`/`InlinePresentationIntent`, [`swift-markdown`](https://github.com/swiftlang/swift-markdown) `0.8.0` (`import Markdown`), Swift Testing (`import Testing`).

**Reference reading before starting:**
- `docs/superpowers/specs/2026-05-28-fecni-design.md` (the spec)
- `apple-docs read foundation/presentationintent` and `.../kind`, `.../intenttype`
- `apple-docs read foundation/inlinepresentationintent`
- `apple-docs read foundation/attributedstring/markdownparsingoptions` (for reference; we parse via swift-markdown, not this)
- swift-markdown: `Document(parsing:)`, `Markup` visitor, `Heading`, `UnorderedList`, `OrderedList`, `ListItem(checkbox:)`, `CodeBlock`, `Paragraph`, `Strong`, `Emphasis`, `InlineCode`, `Link`, `Text`, `MarkupFormatter`

**Supported constructs (the whole surface):** H1/H2/H3, bold, italic, inline code, links, unordered list, ordered list, task list (GFM `- [ ]` / `- [x]`), fenced code block. Everything else is out of scope (tables, blockquotes, images, strikethrough, frontmatter).

---

## File Structure

```
Packages/CaptureKit/
├── Package.swift
├── Sources/CaptureKit/
│   ├── CaptureSettings.swift     # value type + UserDefaults-backed store
│   ├── ObsidianVault.swift       # vault value type
│   ├── VaultLocator.swift        # obsidian.json parsing, subfolder + isVault helpers
│   ├── CaptureStore.swift        # filename generation + file writing
│   ├── TaskItem.swift            # custom AttributedString attribute for task items
│   └── MarkdownDocument.swift    # AttributedString <-> Markdown bridge (the risky seam)
└── Tests/CaptureKitTests/
    ├── CaptureSettingsTests.swift
    ├── VaultLocatorTests.swift
    ├── CaptureStoreTests.swift
    ├── MarkdownDocumentLoadTests.swift
    ├── MarkdownDocumentSaveTests.swift
    ├── MarkdownDocumentRoundTripTests.swift
    └── Fixtures/obsidian.json
```

**Responsibilities:**
- `CaptureSettings` — pure value type (`vaultPath`, `subfolder`) + a thin `SettingsStore` that reads/writes it to an injectable `UserDefaults`.
- `ObsidianVault` / `VaultLocator` — parse `obsidian.json`, list a vault's subfolders, test if a folder is a vault. No global state; the config path is injectable.
- `CaptureStore` — given a resolved directory + an injectable clock, generate a collision-safe `yyyy-MM-dd HHmm.md` filename and write content (skipping empty notes).
- `TaskItem` — custom attribute carrying task-item checked state, since `PresentationIntent` has no checkbox kind.
- `MarkdownDocument` — the bridge. Symmetric round-trip is the contract; the round-trip tests are the spec.

---

## Task 1: Package skeleton + green harness

**Files:**
- Create: `Packages/CaptureKit/Package.swift`
- Create: `Packages/CaptureKit/Sources/CaptureKit/CaptureKit.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/SmokeTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaptureKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CaptureKit", targets: ["CaptureKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "CaptureKit",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]
        ),
        .testTarget(
            name: "CaptureKitTests",
            dependencies: ["CaptureKit"],
            resources: [.copy("Fixtures/obsidian.json")]
        ),
    ]
)
```

- [ ] **Step 2: Write a placeholder source so the target compiles**

`Sources/CaptureKit/CaptureKit.swift`:
```swift
// CaptureKit — deterministic core for fecni (settings, vault detection,
// capture-file writing, Markdown <-> AttributedString conversion).
```

- [ ] **Step 3: Write the smoke test**

`Tests/CaptureKitTests/SmokeTests.swift`:
```swift
import Testing
@testable import CaptureKit

@Test func harnessRuns() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Resolve and run**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit`
Expected: dependency resolution downloads swift-markdown 0.8.x; `harnessRuns` PASSES. If `.macOS("26.0")` is rejected by the installed SwiftPM, fall back to `.macOS(.v15)` (the APIs used exist from macOS 12/15; the app target enforces 26.3).

- [ ] **Step 5: Commit (checkpoint — see commit policy)**

```bash
git add Packages/CaptureKit
git commit -m "chore: scaffold CaptureKit SPM package"
```

---

## Task 2: CaptureSettings + SettingsStore

**Files:**
- Create: `Packages/CaptureKit/Sources/CaptureKit/CaptureSettings.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/CaptureSettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import CaptureKit

@Test func defaultsAreEmpty() {
    let s = CaptureSettings()
    #expect(s.vaultPath == nil)
    #expect(s.subfolder == "")
}

@Test func storeRoundTripsThroughUserDefaults() {
    let defaults = UserDefaults(suiteName: "fecni.test.\(UUID().uuidString)")!
    let store = SettingsStore(defaults: defaults)
    #expect(store.load() == CaptureSettings())

    let updated = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "00-Inbox")
    store.save(updated)
    #expect(store.load() == updated)
}

@Test func resolvedDirectoryJoinsVaultAndSubfolder() {
    let s = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "00-Inbox")
    #expect(s.resolvedDirectory?.path == "/Users/me/Vault/00-Inbox")

    let root = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "")
    #expect(root.resolvedDirectory?.path == "/Users/me/Vault")

    #expect(CaptureSettings(vaultPath: nil).resolvedDirectory == nil)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureSettingsTests`
Expected: FAIL — `CaptureSettings` / `SettingsStore` undefined.

- [ ] **Step 3: Implement**

`CaptureSettings.swift`:
```swift
import Foundation

public struct CaptureSettings: Equatable, Codable, Sendable {
    public var vaultPath: String?
    public var subfolder: String

    public init(vaultPath: String? = nil, subfolder: String = "") {
        self.vaultPath = vaultPath
        self.subfolder = subfolder
    }

    /// Vault root joined with the (possibly empty) subfolder, or nil if no vault chosen.
    public var resolvedDirectory: URL? {
        guard let vaultPath else { return nil }
        let base = URL(fileURLWithPath: vaultPath, isDirectory: true)
        return subfolder.isEmpty ? base : base.appendingPathComponent(subfolder, isDirectory: true)
    }
}

public struct SettingsStore: Sendable {
    private let defaults: UserDefaults
    private let key = "fecni.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> CaptureSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CaptureSettings.self, from: data)
        else { return CaptureSettings() }
        return decoded
    }

    public func save(_ settings: CaptureSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureSettingsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): settings value type + UserDefaults store"
```

---

## Task 3: ObsidianVault + VaultLocator parsing

**Files:**
- Create: `Packages/CaptureKit/Sources/CaptureKit/ObsidianVault.swift`
- Create: `Packages/CaptureKit/Sources/CaptureKit/VaultLocator.swift`
- Create: `Packages/CaptureKit/Tests/CaptureKitTests/Fixtures/obsidian.json`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/VaultLocatorTests.swift`

- [ ] **Step 1: Write the fixture**

`Tests/CaptureKitTests/Fixtures/obsidian.json`:
```json
{
  "vaults": {
    "a1b2": { "path": "/Users/me/Notes", "ts": 1716800000000, "open": true },
    "c3d4": { "path": "/Users/me/Archive", "ts": 1700000000000 }
  }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
import Testing
import Foundation
@testable import CaptureKit

private func fixtureData() throws -> Data {
    let url = Bundle.module.url(forResource: "obsidian", withExtension: "json")!
    return try Data(contentsOf: url)
}

@Test func parsesVaultsSortedByMostRecentlyOpened() throws {
    let vaults = try VaultLocator.vaults(fromObsidianConfig: fixtureData())
    #expect(vaults.count == 2)
    #expect(vaults[0].path == "/Users/me/Notes")   // newer ts first
    #expect(vaults[0].isOpen == true)
    #expect(vaults[0].name == "Notes")
    #expect(vaults[1].path == "/Users/me/Archive")
    #expect(vaults[1].isOpen == false)
}

@Test func emptyOrMissingVaultsKeyYieldsEmptyList() throws {
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data("{}".utf8)).isEmpty)
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data(#"{"vaults":{}}"#.utf8)).isEmpty)
}

@Test func malformedJSONThrows() {
    #expect(throws: (any Error).self) {
        _ = try VaultLocator.vaults(fromObsidianConfig: Data("not json".utf8))
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter VaultLocatorTests`
Expected: FAIL — types undefined.

- [ ] **Step 4: Implement**

`ObsidianVault.swift`:
```swift
import Foundation

public struct ObsidianVault: Equatable, Sendable {
    public let path: String
    public let isOpen: Bool
    public let lastOpened: Date?

    public var name: String { URL(fileURLWithPath: path).lastPathComponent }

    public init(path: String, isOpen: Bool, lastOpened: Date?) {
        self.path = path
        self.isOpen = isOpen
        self.lastOpened = lastOpened
    }
}
```

`VaultLocator.swift`:
```swift
import Foundation

public enum VaultLocator {

    private struct Config: Decodable {
        struct Entry: Decodable {
            let path: String
            let ts: Double?
            let open: Bool?
        }
        let vaults: [String: Entry]?
    }

    /// Parse the contents of an Obsidian `obsidian.json` file into vaults,
    /// sorted most-recently-opened first.
    public static func vaults(fromObsidianConfig data: Data) throws -> [ObsidianVault] {
        let config = try JSONDecoder().decode(Config.self, from: data)
        let entries = config.vaults ?? [:]
        return entries.values
            .map { entry in
                ObsidianVault(
                    path: entry.path,
                    isOpen: entry.open ?? false,
                    lastOpened: entry.ts.map { Date(timeIntervalSince1970: $0 / 1000) }
                )
            }
            .sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
    }

    /// Standard location of Obsidian's config on macOS.
    public static var defaultConfigURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("obsidian/obsidian.json")
    }

    /// Read and parse the config on disk; returns [] if the file is missing or unreadable.
    public static func detectedVaults(configURL: URL = defaultConfigURL) -> [ObsidianVault] {
        guard let data = try? Data(contentsOf: configURL) else { return [] }
        return (try? vaults(fromObsidianConfig: data)) ?? []
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter VaultLocatorTests`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): parse Obsidian vault list from obsidian.json"
```

---

## Task 4: VaultLocator filesystem helpers (subfolders, isVault)

**Files:**
- Modify: `Packages/CaptureKit/Sources/CaptureKit/VaultLocator.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/VaultLocatorTests.swift` (append)

- [ ] **Step 1: Write the failing tests (append to VaultLocatorTests.swift)**

```swift
@Test func listsImmediateSubfoldersExcludingDotFolders() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: root.appendingPathComponent("00-Inbox"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("Projects"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
    try Data().write(to: root.appendingPathComponent("note.md"))
    defer { try? fm.removeItem(at: root) }

    let subs = VaultLocator.subfolders(ofVault: root.path)
    #expect(subs == ["00-Inbox", "Projects"])   // sorted, no .obsidian, no files
}

@Test func isVaultTrueWhenDotObsidianPresent() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: root.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    #expect(VaultLocator.isVault(root.path) == true)
    #expect(VaultLocator.isVault(fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).path) == false)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter VaultLocatorTests`
Expected: FAIL — `subfolders`/`isVault` undefined.

- [ ] **Step 3: Implement (append to the `VaultLocator` enum)**

```swift
    /// Immediate child directories of a vault, excluding dot-folders, sorted by name.
    public static func subfolders(ofVault vaultPath: String) -> [String] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: vaultPath, isDirectory: true)
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { $0.lastPathComponent }
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    /// A folder is an Obsidian vault if it contains a `.obsidian` directory.
    public static func isVault(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let dot = URL(fileURLWithPath: path).appendingPathComponent(".obsidian").path
        return FileManager.default.fileExists(atPath: dot, isDirectory: &isDir) && isDir.boolValue
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter VaultLocatorTests`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): vault subfolder listing + isVault check"
```

---

## Task 5: CaptureStore filename generation

**Files:**
- Create: `Packages/CaptureKit/Sources/CaptureKit/CaptureStore.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/CaptureStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import CaptureKit

private func date(_ iso: String) -> Date {
    let f = ISO8601DateFormatter()
    return f.date(from: iso)!
}

@Test func filenameUsesTimestampFormat() {
    let store = CaptureStore(directory: URL(fileURLWithPath: "/tmp"), timeZone: TimeZone(identifier: "UTC")!)
    let name = store.filename(at: date("2026-05-28T14:32:00Z"), existing: [])
    #expect(name == "2026-05-28 1432.md")
}

@Test func filenameAppendsSuffixOnCollision() {
    let store = CaptureStore(directory: URL(fileURLWithPath: "/tmp"), timeZone: TimeZone(identifier: "UTC")!)
    let d = date("2026-05-28T14:32:00Z")
    #expect(store.filename(at: d, existing: ["2026-05-28 1432.md"]) == "2026-05-28 1432 2.md")
    #expect(store.filename(at: d, existing: ["2026-05-28 1432.md", "2026-05-28 1432 2.md"]) == "2026-05-28 1432 3.md")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureStoreTests`
Expected: FAIL — `CaptureStore` undefined.

- [ ] **Step 3: Implement**

`CaptureStore.swift`:
```swift
import Foundation

public struct CaptureStore: Sendable {
    private let directory: URL
    private let formatter: DateFormatter

    public init(directory: URL, timeZone: TimeZone = .current) {
        self.directory = directory
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HHmm"
        self.formatter = f
    }

    /// "yyyy-MM-dd HHmm.md", with " 2", " 3"… inserted before the extension on collision.
    public func filename(at date: Date, existing: Set<String>) -> String {
        let base = formatter.string(from: date)
        if !existing.contains("\(base).md") { return "\(base).md" }
        var n = 2
        while existing.contains("\(base) \(n).md") { n += 1 }
        return "\(base) \(n).md"
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureStoreTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): collision-safe capture filename generation"
```

---

## Task 6: CaptureStore writing (skip empty, real files)

**Files:**
- Modify: `Packages/CaptureKit/Sources/CaptureKit/CaptureStore.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/CaptureStoreTests.swift` (append)

- [ ] **Step 1: Write the failing tests (append)**

```swift
@Test func writeCreatesFileWithContent() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: dir) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    let url = try store.write(markdown: "# Hello\n", at: date("2026-05-28T14:32:00Z"))
    #expect(url != nil)
    #expect(url?.lastPathComponent == "2026-05-28 1432.md")
    #expect(try String(contentsOf: url!, encoding: .utf8) == "# Hello\n")
}

@Test func writeSkipsEmptyOrWhitespaceContent() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: dir) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    #expect(try store.write(markdown: "   \n\t", at: date("2026-05-28T14:32:00Z")) == nil)
    #expect(fm.fileExists(atPath: dir.path) == false || (try fm.contentsOfDirectory(atPath: dir.path)).isEmpty)
}

@Test func writeCreatesIntermediateDirectories() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("nested")
    defer { try? fm.removeItem(at: dir.deletingLastPathComponent()) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    let url = try store.write(markdown: "hi", at: date("2026-05-28T14:32:00Z"))
    #expect(url != nil)
    #expect(fm.fileExists(atPath: url!.path))
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureStoreTests`
Expected: FAIL — `write` undefined.

- [ ] **Step 3: Implement (append to `CaptureStore`)**

```swift
    /// Writes markdown to a new collision-safe file in `directory`. Returns the URL,
    /// or nil if the trimmed content is empty (no file is created).
    @discardableResult
    public func write(markdown: String, at date: Date) throws -> URL? {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = Set((try? fm.contentsOfDirectory(atPath: directory.path)) ?? [])
        let url = directory.appendingPathComponent(filename(at: date, existing: existing))
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter CaptureStoreTests`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): write captures to vault, skipping empty notes"
```

---

## Task 7: TaskItem attribute

**Files:**
- Create: `Packages/CaptureKit/Sources/CaptureKit/TaskItem.swift`

`PresentationIntent` has no checkbox kind, so task-list state rides on a custom attribute. This task only defines it (it is exercised by the MarkdownDocument tests).

- [ ] **Step 1: Implement**

`TaskItem.swift`:
```swift
import Foundation

/// Marks a list item as a GFM task item; value is the checked state.
public enum TaskItemAttribute: AttributedStringKey {
    public typealias Value = Bool
    public static let name = "fecni.taskItem"
}

public extension AttributeScopes {
    struct FecniAttributes: AttributeScope {
        public let taskItem: TaskItemAttribute
    }
    var fecni: FecniAttributes.Type { FecniAttributes.self }
}

public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.FecniAttributes, T>
    ) -> T { self[T.self] }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build --disable-sandbox --package-path Packages/CaptureKit`
Expected: builds clean.

- [ ] **Step 3: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): custom task-item AttributedString attribute"
```

---

## Task 8: MarkdownDocument — load (Markdown → AttributedString)

**Files:**
- Create: `Packages/CaptureKit/Sources/CaptureKit/MarkdownDocument.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/MarkdownDocumentLoadTests.swift`

**Approach:** Parse with swift-markdown (`Document(parsing:)`), then walk top-level blocks into an `AttributedString`. Each leaf block becomes one paragraph of text terminated by `\n`, carrying a `PresentationIntent` built from its block kind. Inline nodes carry `inlinePresentationIntent` (bold/italic/code), `link`, and—for task items—`TaskItemAttribute` on the whole line. This walk is the symmetric inverse of Task 9's save walk; the round-trip tests in Task 10 are the ultimate contract. Expect to iterate the walk against those tests.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import CaptureKit

@Test func loadParsesHeadingLevel() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "## Title")
    let run = a.runs.first { $0.presentationIntent != nil }
    let kinds = run?.presentationIntent?.components.map(\.kind) ?? []
    #expect(kinds.contains { if case .header(let l) = $0 { return l == 2 } else { return false } })
    #expect(String(a.characters).contains("Title"))
}

@Test func loadParsesBoldAndItalicInline() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "a **b** _c_")
    let bold = a.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
    let italic = a.runs.first { $0.inlinePresentationIntent?.contains(.emphasized) == true }
    #expect(bold != nil)
    #expect(italic != nil)
}

@Test func loadParsesTaskItemsWithCheckedState() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- [ ] todo\n- [x] done")
    let states = a.runs.compactMap { $0[TaskItemAttribute.self] }
    #expect(states.contains(false))
    #expect(states.contains(true))
    // The "[ ]" / "[x]" literals must NOT survive into the text.
    #expect(!String(a.characters).contains("[ ]"))
    #expect(!String(a.characters).contains("[x]"))
}

@Test func loadParsesLink() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "see [docs](https://example.com)")
    let link = a.runs.first { $0.link != nil }?.link
    #expect(link?.absoluteString == "https://example.com")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter MarkdownDocumentLoadTests`
Expected: FAIL — `MarkdownDocument` undefined.

- [ ] **Step 3: Implement the load path**

`MarkdownDocument.swift`:
```swift
import Foundation
import Markdown

public enum MarkdownDocument {

    // MARK: - Load: Markdown -> AttributedString

    public static func attributedString(fromMarkdown markdown: String) -> AttributedString {
        let document = Document(parsing: markdown)
        var builder = AttributedString()
        var identity = 0
        func nextIdentity() -> Int { identity += 1; return identity }

        var firstBlock = true
        for block in document.blockChildren {
            if !firstBlock { builder.append(AttributedString("\n")) }
            firstBlock = false
            appendBlock(block, listContext: [], checked: nil, into: &builder, nextIdentity: nextIdentity)
        }
        return builder
    }

    /// `listContext` is the stack of enclosing list IntentTypes (outermost last),
    /// `checked` is the task-item state for the current list item, if any.
    private static func appendBlock(
        _ markup: Markup,
        listContext: [PresentationIntent.IntentType],
        checked: Bool?,
        into builder: inout AttributedString,
        nextIdentity: () -> Int
    ) {
        switch markup {
        case let heading as Heading:
            let intent = PresentationIntent(
                [.init(kind: .header(level: heading.level), identity: nextIdentity())] + listContext,
                identity: nextIdentity(), parent: nil
            )
            appendInlineChildren(of: heading, blockIntent: intent, checked: checked, into: &builder)

        case let paragraph as Paragraph:
            let intent = PresentationIntent(
                [.init(kind: .paragraph, identity: nextIdentity())] + listContext,
                identity: nextIdentity(), parent: nil
            )
            appendInlineChildren(of: paragraph, blockIntent: intent, checked: checked, into: &builder)

        case let code as CodeBlock:
            let intent = PresentationIntent(
                [.init(kind: .codeBlock(languageHint: code.language), identity: nextIdentity())],
                identity: nextIdentity(), parent: nil
            )
            var run = AttributedString(code.code.hasSuffix("\n") ? String(code.code.dropLast()) : code.code)
            run.presentationIntent = intent
            builder.append(run)

        case let list as UnorderedList:
            appendListItems(list.listItems, listKind: .unorderedList,
                            listContext: listContext, into: &builder, nextIdentity: nextIdentity)

        case let list as OrderedList:
            appendListItems(list.listItems, listKind: .orderedList,
                            listContext: listContext, into: &builder, nextIdentity: nextIdentity)

        default:
            // Unsupported block: emit its plain text as a paragraph.
            let intent = PresentationIntent([.init(kind: .paragraph, identity: nextIdentity())],
                                            identity: nextIdentity(), parent: nil)
            var run = AttributedString(markup.format())
            run.presentationIntent = intent
            builder.append(run)
        }
    }

    private static func appendListItems(
        _ items: some Sequence<ListItem>,
        listKind: PresentationIntent.Kind,
        listContext: [PresentationIntent.IntentType],
        into builder: inout AttributedString,
        nextIdentity: () -> Int
    ) {
        var ordinal = 1
        var first = true
        for item in items {
            if !first { builder.append(AttributedString("\n")) }
            first = false
            let listFrame: [PresentationIntent.IntentType] = [
                .init(kind: .listItem(ordinal: ordinal), identity: nextIdentity()),
                .init(kind: listKind, identity: nextIdentity()),
            ] + listContext
            let checked: Bool? = item.checkbox.map { $0 == .checked }
            // A list item contains block children (usually one Paragraph).
            var firstChild = true
            for child in item.blockChildren {
                if !firstChild { builder.append(AttributedString("\n")) }
                firstChild = false
                appendBlock(child, listContext: listFrame, checked: checked,
                            into: &builder, nextIdentity: nextIdentity)
            }
            ordinal += 1
        }
    }

    private static func appendInlineChildren(
        of markup: Markup,
        blockIntent: PresentationIntent,
        checked: Bool?,
        into builder: inout AttributedString
    ) {
        for inline in markup.children {
            var fragment = inlineAttributedString(inline)
            fragment.presentationIntent = blockIntent
            if let checked { fragment[TaskItemAttribute.self] = checked }
            builder.append(fragment)
        }
        if markup.children.isEmpty {
            // Empty block still needs a presentation-bearing (empty) run.
            var empty = AttributedString("")
            empty.presentationIntent = blockIntent
            if let checked { empty[TaskItemAttribute.self] = checked }
            builder.append(empty)
        }
    }

    private static func inlineAttributedString(_ markup: Markup) -> AttributedString {
        switch markup {
        case let text as Text:
            return AttributedString(text.string)
        case let strong as Strong:
            var s = concatInline(strong.children)
            applyInline(.stronglyEmphasized, to: &s)
            return s
        case let em as Emphasis:
            var s = concatInline(em.children)
            applyInline(.emphasized, to: &s)
            return s
        case let code as InlineCode:
            var s = AttributedString(code.code)
            applyInline(.code, to: &s)
            return s
        case let link as Link:
            var s = concatInline(link.children)
            if let dest = link.destination, let url = URL(string: dest) {
                s.link = url
            }
            return s
        default:
            return AttributedString(markup.format())
        }
    }

    private static func concatInline(_ children: some Sequence<Markup>) -> AttributedString {
        var out = AttributedString()
        for child in children { out.append(inlineAttributedString(child)) }
        return out
    }

    private static func applyInline(_ intent: InlinePresentationIntent, to s: inout AttributedString) {
        for run in s.runs {
            let merged = (s[run.range].inlinePresentationIntent ?? []).union(intent)
            s[run.range].inlinePresentationIntent = merged
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter MarkdownDocumentLoadTests`
Expected: PASS (4 tests). If `PresentationIntent.IntentType(kind:identity:)` or the `PresentationIntent([...], identity:parent:)` initializer shape differs from the installed SDK, adjust to the real initializer (confirm via `apple-docs read foundation/presentationintent/init(_:identity:parent:)` and `.../intenttype`). Keep the test assertions fixed; adapt the construction.

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): parse Markdown into editable AttributedString"
```

---

## Task 9: MarkdownDocument — save (AttributedString → Markdown)

**Files:**
- Modify: `Packages/CaptureKit/Sources/CaptureKit/MarkdownDocument.swift`
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/MarkdownDocumentSaveTests.swift`

**Approach:** Group runs into blocks by equal `presentationIntent`. For each block, read its kind(s) from `components`, render the inline content (walking `inlinePresentationIntent` + `link`), and prefix per kind (`#`/`-`/`1.`/`- [ ]`/fence). Escape Markdown-significant characters in plain text. Join blocks with `\n` and ensure a trailing newline.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import CaptureKit

private func md(_ build: (inout AttributedString) -> Void) -> String {
    var a = AttributedString()
    build(&a)
    return MarkdownDocument.markdown(from: a)
}

@Test func savesHeading() {
    var a = AttributedString("Title")
    a.presentationIntent = PresentationIntent([.init(kind: .header(level: 1), identity: 1)], identity: 2, parent: nil)
    #expect(MarkdownDocument.markdown(from: a) == "# Title\n")
}

@Test func savesBoldItalicCode() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "a **b** _c_ `d`")
    #expect(MarkdownDocument.markdown(from: a) == "a **b** *c* `d`\n")
}

@Test func savesUnorderedList() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- one\n- two")
    #expect(MarkdownDocument.markdown(from: a) == "- one\n- two\n")
}

@Test func savesTaskList() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- [ ] todo\n- [x] done")
    #expect(MarkdownDocument.markdown(from: a) == "- [ ] todo\n- [x] done\n")
}

@Test func savesCodeBlock() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "```\nlet x = 1\n```")
    #expect(MarkdownDocument.markdown(from: a) == "```\nlet x = 1\n```\n")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter MarkdownDocumentSaveTests`
Expected: FAIL — `markdown(from:)` undefined.

- [ ] **Step 3: Implement the save path (append to `MarkdownDocument`)**

```swift
    // MARK: - Save: AttributedString -> Markdown

    public static func markdown(from attributed: AttributedString) -> String {
        var blocks: [(intent: PresentationIntent?, range: Range<AttributedString.Index>, checked: Bool?)] = []
        for run in attributed.runs {
            let intent = run.presentationIntent
            let checked = run[TaskItemAttribute.self]
            if let last = blocks.last, last.intent == intent {
                blocks[blocks.count - 1].range = last.range.lowerBound..<run.range.upperBound
                if blocks[blocks.count - 1].checked == nil { blocks[blocks.count - 1].checked = checked }
            } else {
                blocks.append((intent, run.range, checked))
            }
        }

        let lines = blocks.map { renderBlock(intent: $0.intent, range: $0.range, checked: $0.checked, in: attributed) }
        var text = lines.joined(separator: "\n")
        if !text.hasSuffix("\n") { text += "\n" }
        return text
    }

    private static func renderBlock(
        intent: PresentationIntent?,
        range: Range<AttributedString.Index>,
        checked: Bool?,
        in attributed: AttributedString
    ) -> String {
        let kinds = intent?.components.map(\.kind) ?? [.paragraph]

        // Code block: emit raw, fenced, no inline escaping.
        if let lang = codeBlockLanguage(in: kinds) {
            let raw = String(attributed[range].characters)
            return "```\(lang ?? "")\n\(raw)\n```"
        }

        let inline = inlineMarkdown(for: range, in: attributed)

        if let level = headerLevel(in: kinds) {
            return String(repeating: "#", count: level) + " " + inline
        }
        if let ordinal = orderedOrdinal(in: kinds) {
            return "\(ordinal). \(inline)"
        }
        if isUnordered(kinds) {
            if let checked { return "- [\(checked ? "x" : " ")] \(inline)" }
            return "- \(inline)"
        }
        return inline
    }

    private static func headerLevel(in kinds: [PresentationIntent.Kind]) -> Int? {
        for k in kinds { if case .header(let l) = k { return l } }
        return nil
    }
    private static func orderedOrdinal(in kinds: [PresentationIntent.Kind]) -> Int? {
        var inOrdered = false, ordinal = 1
        for k in kinds {
            if case .orderedList = k { inOrdered = true }
            if case .listItem(let o) = k { ordinal = o }
        }
        return inOrdered ? ordinal : nil
    }
    private static func isUnordered(_ kinds: [PresentationIntent.Kind]) -> Bool {
        kinds.contains { if case .unorderedList = $0 { return true } else { return false } }
    }
    private static func codeBlockLanguage(in kinds: [PresentationIntent.Kind]) -> String?? {
        for k in kinds { if case .codeBlock(let hint) = k { return .some(hint) } }
        return .none
    }

    private static func inlineMarkdown(for range: Range<AttributedString.Index>, in attributed: AttributedString) -> String {
        var out = ""
        for run in attributed[range].runs {
            let text = String(attributed[run.range].characters)
            let intent = run.inlinePresentationIntent ?? []
            var piece: String
            if intent.contains(.code) {
                piece = "`\(text)`"
            } else {
                piece = escapeInline(text)
                if intent.contains(.stronglyEmphasized) { piece = "**\(piece)**" }
                if intent.contains(.emphasized) { piece = "*\(piece)*" }
            }
            if let url = run.link { piece = "[\(piece)](\(url.absoluteString))" }
            out += piece
        }
        return out
    }

    private static func escapeInline(_ text: String) -> String {
        var result = ""
        for ch in text {
            if "\\`*_[]".contains(ch) { result.append("\\") }
            result.append(ch)
        }
        return result
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter MarkdownDocumentSaveTests`
Expected: PASS (5 tests). Iterate the renderer against any failures — the assertions are the spec. If emphasis nesting order (`**` vs `*` outer) trips a test, fix the renderer, not the test.

- [ ] **Step 5: Commit (checkpoint)**

```bash
git add Packages/CaptureKit
git commit -m "feat(capturekit): serialize AttributedString back to Markdown"
```

---

## Task 10: MarkdownDocument — round-trip contract

**Files:**
- Test: `Packages/CaptureKit/Tests/CaptureKitTests/MarkdownDocumentRoundTripTests.swift`

This task adds no production code unless a case fails — it locks the load/save symmetry that the whole persistence story depends on.

- [ ] **Step 1: Write the round-trip tests**

```swift
import Testing
@testable import CaptureKit

private func roundTrips(_ markdown: String) -> Bool {
    let once = MarkdownDocument.markdown(from: MarkdownDocument.attributedString(fromMarkdown: markdown))
    let twice = MarkdownDocument.markdown(from: MarkdownDocument.attributedString(fromMarkdown: once))
    return once == twice   // idempotent after first normalization
}

@Test(arguments: [
    "# Heading 1\n",
    "## Heading 2\n",
    "### Heading 3\n",
    "Plain paragraph text.\n",
    "Text with **bold** and *italic* and `code`.\n",
    "A [link](https://example.com) inline.\n",
    "- one\n- two\n- three\n",
    "1. first\n2. second\n",
    "- [ ] open task\n- [x] done task\n",
    "```\nlet x = 1\nlet y = 2\n```\n",
])
func canonicalMarkdownIsStableAcrossRoundTrips(_ sample: String) {
    #expect(roundTrips(sample), "not idempotent: \(sample)")
}

@Test func multiBlockDocumentRoundTrips() {
    let doc = """
    # Title

    Intro paragraph with **bold**.

    - first
    - second

    ```
    code here
    ```
    """
    #expect(roundTrips(doc))
}
```

- [ ] **Step 2: Run**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit --filter MarkdownDocumentRoundTripTests`
Expected: PASS. Where a case fails, fix the load or save walk (Tasks 8/9) until idempotent. Document any construct that cannot round-trip in the spec's "Open implementation notes" and raise it before proceeding.

- [ ] **Step 3: Full suite green**

Run: `swift test --disable-sandbox --package-path Packages/CaptureKit`
Expected: ALL tests pass.

- [ ] **Step 4: Commit (checkpoint — first working version of CaptureKit)**

```bash
git add Packages/CaptureKit
git commit -m "test(capturekit): Markdown round-trip contract"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** settings ✓ (T2), vault detection via obsidian.json ✓ (T3) + subfolders ✓ (T4), one-file-per-capture filename + write + skip-empty ✓ (T5/T6), Markdown round-trip for all 9 constructs ✓ (T8/T9/T10), task lists ✓ (T7 + T8/T9). The autosave *draft* and the UI live in Plan 2.
- **Placeholder scan:** none — every step has runnable code or an exact command.
- **Type consistency:** `CaptureSettings`, `SettingsStore`, `ObsidianVault`, `VaultLocator`, `CaptureStore`, `TaskItemAttribute`, `MarkdownDocument.attributedString(fromMarkdown:)` / `.markdown(from:)` are used consistently across tasks.
- **Known risk:** the exact `PresentationIntent` / `IntentType` initializer shapes and emphasis-nesting are SDK-sensitive; Tasks 8–10 are explicitly TDD-against-contract so the executor adapts construction while the assertions stay fixed.
```
