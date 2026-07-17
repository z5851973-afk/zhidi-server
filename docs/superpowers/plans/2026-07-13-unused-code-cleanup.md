# App Unused Code Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove clearly temporary, unused app artifacts without changing owner or worker app behavior, while retaining regression tests and runtime fixture data.

**Architecture:** Treat entry-point reachability, import references, analyzer diagnostics, and test coverage as independent evidence. Delete only artifacts with unambiguous generated/backup provenance; retain unreferenced feature pages when future routing intent is plausible.

**Tech Stack:** Flutter, Dart analyzer, flutter_test

## Global Constraints

- Preserve all pre-existing worktree changes.
- Do not remove runtime mock data that currently powers app screens.
- Keep regression tests for navigation, responsive layout, splash flow, pricing detail, and renovation budget behavior.
- Verify owner-authored sources separately from generated dependency/build trees.

---

### Task 1: Remove temporary artifacts

**Files:**
- Delete: `zhidi_app/lib/pages/price/worker_quote_page_20260709_113951_873.dart`
- Delete: `zhidi_app/lib/pages/price/construction_project_detail_page_20260712_210844_530.dart`
- Delete: `zhidi_app/lib/pages/profile/favorites_page_20260709_114109_341.dart`
- Delete: `.DS_Store` files under `zhidi_app/`

**Interfaces:**
- Consumes: current imports from `zhidi_app/lib/` and `zhidi_app/test/`
- Produces: a source tree without timestamp backups or Finder metadata

- [ ] **Step 1: Confirm no imports reference timestamp backups**

Run: `rg -n "_(20260709_113951_873|20260712_210844_530|20260709_114109_341)" zhidi_app/lib zhidi_app/test`
Expected: no output.

- [ ] **Step 2: Delete the confirmed temporary files and Finder metadata**

Delete only the three timestamp backup files and `.DS_Store` files under `zhidi_app/`.

- [ ] **Step 3: Confirm no timestamp backup remains**

Run: `find zhidi_app/lib -type f -regex '.*_[0-9]\{8\}_[0-9]\{6\}_[0-9]\{3\}\.dart' -print`
Expected: no output.

### Task 2: Isolate static analysis from generated trees

**Files:**
- Modify: `zhidi_app/analysis_options.yaml`

**Interfaces:**
- Consumes: generated output under nested `build/` directories
- Produces: analyzer exclusions for `**/build/**`

- [ ] **Step 1: Add the generated-tree exclusion**

Add:

```yaml
analyzer:
  exclude:
    - '**/build/**'
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: no errors or warnings from app-authored code; informational lints may remain.

### Task 3: Verify retained regression coverage

**Files:**
- Test: `zhidi_app/test/*.dart`

**Interfaces:**
- Consumes: retained production code and fixture data
- Produces: evidence that cleanup does not change app behavior

- [ ] **Step 1: Run the complete Flutter test suite**

Run: `flutter test`
Expected: all retained tests pass.

- [ ] **Step 2: Review the final diff**

Run: `git diff --check && git status --short -- zhidi_app/analysis_options.yaml zhidi_app/lib zhidi_app/test`
Expected: no whitespace errors; only intended cleanup plus pre-existing user changes appear.
