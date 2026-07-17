# 工匠端骨架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first-pass工匠端骨架 with首页、施工单、消息、我的四个入口，承接施工流程、阶段确认、每日水印照片和基础工匠资料展示。

**Architecture:** Reuse the existing OwnerAppPreview SwiftUI style and sample-data approach, but split the工匠端 into focused views so each screen has one job. Add a small set of foreman-specific model fixtures and a dedicated shell with tab navigation, then wire each tab to the existing装修业务 flow instead of creating a separate ad hoc UI.

**Tech Stack:** SwiftUI, Swift Package preview target, existing `OwnerAppPreview` models/tests, SnapshotPreviews host.

---

### Task 1: Add foreman shell models and sample data

**Files:**
- Modify: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/Models.swift`
- Test: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testForemanShellSampleDataCoversWorkOrderMessagingAndProfile() {
    let shell = ForemanShell.samples[0]
    XCTAssertEqual(shell.tabs.map(\.title), ["首页", "施工单", "消息", "我的"])
    XCTAssertFalse(shell.currentWorkOrder.stages.isEmpty)
    XCTAssertFalse(shell.dailyPhotos.isEmpty)
    XCTAssertFalse(shell.conversations.isEmpty)
    XCTAssertFalse(shell.profile.certifiedTrades.isEmpty)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testForemanShellSampleDataCoversWorkOrderMessagingAndProfile`
Expected: fail because `ForemanShell` and related sample types do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
public struct ForemanShell: Identifiable, Hashable, Sendable {
    public let id: String
    public let tabs: [ForemanShellTab]
    public let currentWorkOrder: ForemanWorkOrder
    public let dailyPhotos: [ForemanDailyPhoto]
    public let conversations: [Conversation]
    public let profile: ForemanProfile

    public static let samples: [ForemanShell] = [
        .init(
            id: "foreman-shell",
            tabs: [
                .init(id: "home", title: "首页"),
                .init(id: "workorder", title: "施工单"),
                .init(id: "messages", title: "消息"),
                .init(id: "profile", title: "我的")
            ],
            currentWorkOrder: .sample,
            dailyPhotos: .samples,
            conversations: Conversation.samples,
            profile: .sample
        )
    ]
}

public struct ForemanShellTab: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
}

public struct ForemanWorkOrder: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let ownerName: String
    public let projectName: String
    public let currentStage: String
    public let stageProgress: Int
    public let stages: [ConstructionStageRecord]

    public static let sample = ForemanWorkOrder(
        id: "work-order-1",
        title: "全屋翻新",
        ownerName: "王女士",
        projectName: "锦城小区 3 室 2 厅",
        currentStage: "拆改",
        stageProgress: 40,
        stages: ConstructionProject.samples[0].stageRecords
    )
}

public struct ForemanDailyPhoto: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let caption: String
    public let location: String
    public let createdAt: String

    public static let samples: [ForemanDailyPhoto] = [
        .init(id: "photo-1", title: "水电开槽完成", caption: "强弱电分开走线，点位已标记", location: "成都市 武侯区", createdAt: "今天 17:42"),
        .init(id: "photo-2", title: "拆改清运结束", caption: "旧墙体拆除后，现场已清理", location: "成都市 武侯区", createdAt: "今天 12:18")
    ]
}

public struct ForemanProfile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let district: String
    public let rating: Double
    public let completedProjects: Int
    public let certifiedTrades: [String]
    public let serviceAreas: [String]

    public static let sample = ForemanProfile(
        id: "foreman-profile-1",
        name: "周工长",
        district: "武侯区",
        rating: 4.9,
        completedProjects: 82,
        certifiedTrades: ["拆除", "水电"],
        serviceAreas: ["武侯区", "高新区", "锦江区"]
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter testForemanShellSampleDataCoversWorkOrderMessagingAndProfile`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OwnerAppPreview/Models.swift Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift
git commit -m "feat: add foreman shell sample data"
```

### Task 2: Add the foreman app shell and bottom tab navigation

**Files:**
- Create: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanAppShell.swift`
- Modify: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/OwnerAppPreview.swift`
- Test: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testForemanAppShellCanInitializeWithSampleData() {
    let shell = ForemanShell.samples[0]
    let view = ForemanAppShellView(shell: shell)
    XCTAssertNotNil(view)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testForemanAppShellCanInitializeWithSampleData`
Expected: fail because `ForemanAppShellView` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct ForemanAppShellView: View {
    let shell: ForemanShell
    @State private var selectedTab: String = "home"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch selectedTab {
                case "workorder":
                    ForemanWorkOrderHomeView(shell: shell)
                case "messages":
                    ForemanMessageCenterView(shell: shell)
                case "profile":
                    ForemanProfileView(shell: shell)
                default:
                    ForemanHomeView(shell: shell)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ForemanTabBar(selection: $selectedTab)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter testForemanAppShellCanInitializeWithSampleData`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OwnerAppPreview/ForemanAppShell.swift Sources/OwnerAppPreview/OwnerAppPreview.swift Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift
git commit -m "feat: add foreman app shell"
```

### Task 3: Build the foreman home and work order screens

**Files:**
- Create: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanHomeView.swift`
- Create: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanWorkOrderView.swift`
- Modify: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanAppShell.swift`
- Test: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testForemanHomeShowsCurrentWorkAndTodayActions() {
    let shell = ForemanShell.samples[0]
    let home = ForemanHomeView(shell: shell)
    XCTAssertNotNil(home)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testForemanHomeShowsCurrentWorkAndTodayActions`
Expected: fail until the views exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct ForemanHomeView: View {
    let shell: ForemanShell

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForemanSummaryCard(profile: shell.profile, workOrder: shell.currentWorkOrder)
                ForemanTodayActionsCard()
                ForemanDailyFeedCard(dailyPhotos: shell.dailyPhotos)
                BottomChromeSpacer()
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter testForemanHomeShowsCurrentWorkAndTodayActions`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OwnerAppPreview/ForemanHomeView.swift Sources/OwnerAppPreview/ForemanWorkOrderView.swift Sources/OwnerAppPreview/ForemanAppShell.swift Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift
git commit -m "feat: add foreman home and work order screens"
```

### Task 4: Build foreman messages and profile screens

**Files:**
- Create: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanMessageCenterView.swift`
- Create: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanProfileView.swift`
- Modify: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/ForemanAppShell.swift`
- Test: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testForemanMessagesAndProfileInitializeFromSampleData() {
    let shell = ForemanShell.samples[0]
    XCTAssertFalse(shell.conversations.isEmpty)
    XCTAssertFalse(shell.profile.serviceAreas.isEmpty)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testForemanMessagesAndProfileInitializeFromSampleData`
Expected: fail until the views and data are wired.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct ForemanMessageCenterView: View {
    let shell: ForemanShell

    var body: some View {
        List {
            Section("施工群聊") {
                ForEach(shell.conversations) { conversation in
                    NavigationLink {
                        ChatThreadView(conversation: conversation)
                    } label: {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
        }
    }
}
```

```swift
import SwiftUI

struct ForemanProfileView: View {
    let shell: ForemanShell

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForemanProfileHero(profile: shell.profile)
                ForemanProfileSection(title: "认证工种", rows: shell.profile.certifiedTrades)
                ForemanProfileSection(title: "服务区域", rows: shell.profile.serviceAreas)
                BottomChromeSpacer()
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter testForemanMessagesAndProfileInitializeFromSampleData`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OwnerAppPreview/ForemanMessageCenterView.swift Sources/OwnerAppPreview/ForemanProfileView.swift Sources/OwnerAppPreview/ForemanAppShell.swift Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift
git commit -m "feat: add foreman messages and profile screens"
```

### Task 5: Wire previews and verify the simulator shell

**Files:**
- Modify: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Sources/OwnerAppPreview/OwnerAppPreview.swift`
- Test: `/Users/liupei/Documents/zhidi/.worktrees/backend-mvp/apps/owner-ios/Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testForemanShellPreviewEntryUsesSampleData() {
    let shell = ForemanShell.samples[0]
    XCTAssertEqual(shell.tabs.count, 4)
    XCTAssertEqual(shell.currentWorkOrder.stageProgress, 40)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testForemanShellPreviewEntryUsesSampleData`
Expected: fail until the preview entry is wired to the new shell.

- [ ] **Step 3: Write minimal implementation**

```swift
#Preview("工匠端首页") {
    ForemanAppShellView(shell: ForemanShell.samples[0])
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter testForemanShellPreviewEntryUsesSampleData`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OwnerAppPreview/OwnerAppPreview.swift Tests/OwnerAppPreviewTests/OwnerAppPreviewTests.swift
git commit -m "feat: wire foreman shell preview"
```

## Self-Review

- Spec coverage: The plan covers the foreman shell, four tabs, sample data, and preview wiring.
- Placeholder scan: No TBD/TODO/implement later language.
- Type consistency: `ForemanShell`, `ForemanShellTab`, `ForemanWorkOrder`, `ForemanDailyPhoto`, and `ForemanProfile` are introduced once and reused consistently.
- Scope check: This plan is one subsystem only; it does not mix in owner-side redesign or backend APIs.

