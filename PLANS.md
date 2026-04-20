# Plan: Sleep Analysis Ship-to-E2E Review

## Goal
Produce a deep gap analysis for the `sleep_analysis` module, identify what must be fixed or refactored to ship true end-to-end, and define a concrete verification plan spanning backend live-DB, Flutter flow tests, and real-device integration coverage.

## Scope
- Active repo: `D:\DoAn2\VSmartwatch\health_system`
- Related repos: none
- Allowed write scope: planning artifacts only for this task unless implementation is requested later
- Git scope: `D:\DoAn2\VSmartwatch\health_system`

## Current Phase
Phase 4

## Phases
### Phase 1: Discovery
- [x] Confirm current plan/state artifacts in repo
- [x] Trace mobile screens, provider, repository, home preview, and routing
- [x] Trace backend ingest/read routes and monitoring service contract
- [x] Capture current automated coverage and known gaps
- **Status:** complete

### Phase 2: Risk Analysis
- [x] Identify correctness, contract, navigation, and state-management risks
- [x] Separate ship blockers from follow-up improvements
- [x] Identify refactors required for deterministic E2E coverage
- **Status:** complete

### Phase 3: Test Strategy
- [x] Define backend live-DB / HTTP verification matrix
- [x] Define Flutter widget-flow and real-device integration matrix
- [x] Define linked-profile, no-data, before-6AM, and canonical `sleep_date` matrix
- [x] Define device validation checklist and evidence capture
- **Status:** complete

### Phase 4: Delivery
- [x] Summarize findings with file references
- [x] State open risks and unverified assumptions
- [x] Provide recommended implementation order
- **Status:** in_progress

## Key Questions
1. Does the current mobile flow preserve one canonical `sleep_date` contract from dashboard preview to report/detail/history and linked profile?
2. Are ingest + latest/history routes aligned on auth, `X-Target-Profile-Id`, and `sleep_date` semantics?
3. What refactors are required so real-device tests can be deterministic rather than brittle?
4. What is still missing between provider/widget confidence and ship-level confidence?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use repo-local planning artifacts for this analysis | The task is hard and spans many reads; persistent notes reduce drift |
| Keep work local without subagents | Environment policy only allows delegation when the user explicitly asks for it |
| Use working-tree code and fresh test output as source of truth over stale plan references | Sleep readiness claims in `plans/E2E/full-e2e-matrix.md` are stronger than the actual device-level evidence in the repo snapshot |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `python` launcher unavailable in shell | 1 | Switched to direct PowerShell/native inspection and venv executables |
| Bundled `rg.exe` access denied in this shell context | 1 | Switched to `Get-ChildItem`/`Get-Content`/GitNexus tools |
| `flutter test` could not write `.flutter_tool_state` in sandbox | 1 | Re-ran with approval outside sandbox |
| Live DB E2E sandbox launch returned access denied | 1 | Re-ran outside sandbox and captured real failures |

## Notes
- User referenced `plans/sleep/README.md`, but that file is not present in the current repo snapshot.
- Verification in this turn includes rerunning the existing backend/Flutter suites and the live DB E2E gate for sleep.
