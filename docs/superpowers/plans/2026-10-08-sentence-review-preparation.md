# Current-Catalog Sentence Review Preparation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Preserve phase-by-phase execution and use scoped agents when helpful. Centralize Tuist/builds and shared-file edits.

**Tech Stack:** iOS 18, Swift 5, SwiftUI, SwiftData, Tuist; AVFoundation for pronunciation; Python standard library for sentence tooling.

**Spec:** ../specs/2026-10-08-study-lists-pronunciation-goals-design.md (approved).

## Global Constraints

- Local only: no accounts, sync, runtime corpus fetches or network-dependent product UI.
- Preserve learner IDs, saved meanings, AI notes, Add next order/cursors and existing review schedules.
- Follow DESIGN.md / Forest, existing composer and state/send patterns, native routing and explicit loading/empty/error states.
- VoiceOver and TestFlight remain deferred.
- Sentence publication requires fluent human decisions; no AI-generated approval.
- Native navigation routes must be included in AppNavigationStack.isPushed.
- Workers own explicit files, are not alone, and must not revert others. Shared backup/Composer/routing edits belong to the coordinator.

**Goal:** Prepare a human-review batch tied to current dictionary study senses; publish only externally approved decisions.

**Architecture:** Keep raw snapshot/source hashes immutable. Add deterministic current-catalog reconciliation and context hashes to the existing approval pipeline. Export a small pending review batch; existing runtime cards remain optional and empty without approvals.

## Review Focus

- Homographs/shared readings must never inherit an approval for another study sense.
- Changed selected meaning or source text must invalidate prior approval.
- Pending/rejected/AI-generated decisions must not reach the bundle.
- Missing/ambiguous mapping must remain unresolved with its cause.
- Source IDs/credits/license and verified-reading provenance must survive publication.

### Task 1: current-catalog reconciliation and review batch

**Create:** tools/data/prepare_current_examples.py, test_current_examples.py; data/tatoeba/current-n5-review-sheet.csv, current-reconciliation.json.
**Modify:** tools/data/export_review_sheet.py, build_approved_examples.py, test_approved_examples.py; data/tatoeba/README.md.

**Interfaces:** Python reconcile(candidates, catalog, legacy_map) returns candidate records with exact catalogID, selectedStudyMeanings, contextSha256 and pending/unresolved state. Use current catalog's explicit legacy mapping only; unresolved or multiple matching sense identities are not automatically approved. Context hash covers exact catalog identity/headword/reading/level/studyMeanings with deterministic JSON encoding.

```python
payload = {key: word[key] for key in ('id', 'headword', 'reading', 'level', 'studyMeanings')}
context_hash = hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()
# Decisions must match candidate IDs, context hash and both source hashes.
if decision['status'] != 'approved':
    continue
```

- [ ] Test exact legacy mapping, retired/ambiguous mapping, multiple selected senses, changed context hash and source text, stable ordering and unchanged raw snapshot. Confirm the known ああ wrong-sense example remains pending/rejected, never automatically approved.
- [ ] Run RED. Produce a pending batch of up to 30 distinct eligible N5 study identities, one candidate each ordered by current catalog position and source numeric IDs. Include all sense notes, current study meanings, source texts/IDs/hashes and blank human reviewer/date/decision/reason fields. Also retain a full reconciliation report so omitted candidates remain inspectable.
- [ ] Extend the approval ledger to version 2 keyed by catalog identity/context hash plus exact sentence IDs. Keep version-1 fixture/empty-ledger handling explicitly tested. Reject approvals without current context hash, reviewer/date/sense rationale, exact text hashes or attribution. Do not silently migrate a legacy approval across changed context.
- [ ] Run all Python data tests. Preserve the zero-approved production bundle. Commit `Prepare current dictionary sentence review batch` and provide its local path to the user.

### Task 2: reviewed publication (external dependency)

**Modify only after human decisions:** data/tatoeba/approvals.json, approved-examples.json, approved-coverage.json; Frameworks/DataKit/Resources/examples-n5.json and offline credits. If runtime identity metadata requires extension, modify Frameworks/DataKit/Sources/Repository/ExampleRepository.swift, Frameworks/DataKit/Tests/ExampleRepositoryTests.swift, Frameworks/SwiftUIApps/Sources/Presentations/Details/DetailViewModel.swift and Frameworks/SwiftUIApps/Sources/Presentations/Review/ReviewSession.swift alongside it.

- [ ] Receive fluent human decisions with reviewer credit/date/sense rationale; record approved and rejected statuses exactly. This step cannot be satisfied by agent inference or fabricated reviewer metadata.
- [ ] Run deterministic builder with source/current-context hashes, emitting only approved examples. Retain Japanese/English sentence IDs, source URLs, owner nulls, license and verified reading/change notes. Reject orphan/current-sense mismatches before generating the app bundle.
- [ ] Test exact current-sense lookup, absent/invalid optional resources and no sentence shown before reveal. Update coverage with actual approved counts, verify offline source credits and long cards in light/dark/XXXL. Full suite/Release and commit `Publish reviewed N5 sentence examples` only after the content gate passes.

## Publication boundary

Task 1 can complete with no reviewer input. Task 2 remains an explicit external dependency; finish all unaffected app phases and report the pending review batch without claiming published examples.

## Verification command convention

After new sources/tests, run `tuist generate --no-open` centrally. Observe the named new tests failing before implementation, then passing. Focused simulator command:

```sh
xcodebuild -workspace JapaneseDictionary.xcworkspace -scheme JapaneseDictionary-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DataKitTests
```

Replace the final selector with the named framework/class for the task. Prefer configured XcodeBuildMCP test tools when available. End each phase with the full workspace suite, app Release build, Python regressions when affected, and `git diff --check`. Commit verified phase work locally; no push/merge during implementation.
