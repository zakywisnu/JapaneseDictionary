# Execution ledger — docs/superpowers/plans/2026-10-06-study-features.md

User approved phase-by-phase implementation with orchestration when useful. Preserve the dataset preparation and plan already in this workspace. Do not push or merge during this execution.

Ruling: use a feature branch in the existing checkout rather than a new worktree — the user-approved dataset and plan are uncommitted here and shared workers need the same prepared inputs.
Ruling: use scoped worker agents as iOS/Python implementers — this harness has no ios-engineer role; repository architecture instructions take precedence over unrelated project profiles.
Ruling: phase 4 publication requires human content approval — implement the pipeline and UI with an empty approved bundle, without representing AI analysis as human approval. Continue unaffected phases.

Pre-flight: Tasks 1–2 share ReviewItem/session/VM; execute serially. Task 3 adds saved-ID schedules required by Task 5. Task 4 Python tooling is independent and may run alongside Task 1; its app integration waits for Review contracts. Backup uses the same store, so sequence it after scheduling.

Status: Task 1 implementation starting. Task 4 approval-tooling preparation starting. No app code changed yet.

Task 3/5 audit ruling: ArrayString is Codable, not a SwiftData model. Current progress counters accumulate across level changes; export/restore preserves counters exactly rather than enforcing the plan's incorrect active-level interpretation. Both bundled parsers generate UUIDs; persistent scheduling always keys saved IDs.

Task 1: implementation and 11 SwiftUIApps tests/app build passed; independent review found no Critical/Important issues. Runtime sheet dismissal/back/theme QA pending.
Task 2: RED observed missing rate/remainingCount/presentationRevision and PracticeQueue, production now ready for GREEN.
Task 4 tooling: 12 Python tests green; 863-row human worksheet prepared; durable local raw archive hash-verified but ignored by Git; generated approved examples remain empty. Runtime loader/card/source integration ready for tests; human publication gate still pending.

2026-10-07 resumed: process-local worker/tool sessions were restarted; new scoped due_ui, backup_layer, storage_review workers continue existing files. SwiftUIApps 11 tests green before due changes. Due persistence RED observed missing due/recordRating; Backup RED observed missing CatalogSnapshot/BackupRepository/BackupPreferences.
Task 3 review: independent storage review found unrated items could be hidden after backwards clock adjustment. Regraded important and assigned test/fix to due UI worker; other examined persistence/scheduler contracts clean.
Ruling: backup progress is optional to preserve genuinely empty fresh stores; multiple records rejected. Restore marks onboarding complete and regenerates the defaults shadow only after success.
Ruling: production source credits omit build checksums/pipeline details; full provenance remains in dataset docs/manifests. No examples are claimed approved.

2026-10-07 verification: DataKit 19/19 and DomainKit 14/14 passed. Includes old three-model disk-store upgrade, backup replacement and disk reopening, rollback/recovery failures, post-success preference publication, cumulative counters, and backwards-clock first review. Backup UI RED confirmed missing BackupViewModel before implementation. Task 2 pure queue/rating tests pass as part of these suites; final SwiftUI integration and visual QA remain pending.

Final 2026-10-07 verification: 54/54 workspace tests and 12/12 Python tests passed; production app build and git diff --check pass. Independent review fixes: populated backups require progress (empty fresh stores may omit it); completed due sessions cannot restart stale snapshots. Both were observed RED then GREEN. Task 1–3 and Task 5 implementation complete. Task 4 infrastructure complete, zero approved content; fluent human review and external raw release archive still pending.

Simulator QA: Words due recall/reveal/one-item Again/completion/back reload; Words and Kanji collection setup/start; N1 empty selection disabled with guidance; native back; long kanji answer with fixed safe-area actions; backup screen, validated current-export preview and destructive confirmation; light/dark and accessibility-large. System exporter opens. Final live-simulator restore confirmation rejected by automatic approval review (replacement of live collection); approval requested, unaffected checks completed. Successful/failed transactional restore, changed fixtures, reopening, cancellation and preferences are automated-tested. VoiceOver deferred; no claim of full Files save/import or final live UI restore. Temporary composer/app-tab harnesses removed, original simulator appearance/text size restored.

2026-10-07 18:23 Asia/Jakarta: user explicitly approved final simulator restore. Restored freshly exported current snapshot via destructive UI confirmation; returned to Progress with Backup restored and Share recovery backup, retaining 1 word and 2 kanji. Recovery JSON verified on disk (1940 bytes, format 1, 1 word, 2 kanji, 1 review, progress present). Temporary preview/app-tab setup removed; production app rebuilt/relaunched successfully, diff check clean. This resolves the earlier approval-blocked UI confirmation. Full system Files save/import picker interaction still not claimed.

2026-10-07: user approved continuing with commit, push and an open PR for review. This supersedes the execution's earlier no-push ruling; merge is not authorized for this delivery. Fresh pre-commit verification: 54 Swift and 12 Python tests pass. Full Files picker save/import and fluent sentence approval remain explicit PR limitations.
