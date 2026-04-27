# Task 03 — Clean separation of fetch / process / visualize phases

Branch: `refactor/03-separate-phases`

## Goal
Tighten the boundaries between phases 1, 2, and 3 so that regenerating a visual for a new storm only requires re-running phase 3 with new config inputs — no leakage of fetch logic into process, or process logic into visualize.

## Why
- REFACTOR.md is explicit: "do not change the overall phase structure" but priority #3 asks for clearer separation so "when the visual is regenerated for new storms it is easy to update and customize."
- Today phase 3 ([3_visualize.R](3_visualize.R)) does heavy data prep — `p3_flow_by_time` computes `above_flood`, `flood_status`, `sev_rank`, `above_amt`, etc. — that belongs in phase 2.
- `p3_global_max_flooded` and `p3_global_max_flood_duration` are aggregation, not visualization.

## Affected files
- [3_visualize.R](3_visualize.R) — strip data-prep targets; keep only viz/animation
- [2_process.R](2_process.R) — receive moved targets (flood_status classification, sev_rank, above_amt, global maxes)
- [2_process/src/](2_process/src/) — possibly add `classify_flood_status.R`
- [3_visualize/src/](3_visualize/src/) — visualize layer should consume fully-processed inputs

## Stepwise plan
1. Audit each `p3_*` target. Classify as `prep` (move to phase 2) vs `viz` (stays).
   - Move: `p3_flow_by_time` flood classification, `p3_global_max_flooded`, `p3_global_max_flood_duration`, `p3_progress_fract` math.
   - Keep: frame rendering, gif assembly, title/end frames.
2. Create new `p2_*` targets receiving the moved logic; keep timestamp-branched shape so phase 3 still maps cleanly.
3. In phase 3, replace inline data prep with reads of the new phase-2 targets.
4. Verify phase boundaries by inspection: phase 1 = I/O only; phase 2 = transforms; phase 3 = renders + gif.
5. Document the contract (one-line comment at top of each phase's `.R` listing inputs/outputs).

## Success criteria
- Phase 3 file shrinks substantially; no `case_when`/`mutate`/`group_by` data prep remains in `3_visualize.R`.
- Re-running just `tar_make(starts_with("p3_"))` regenerates the animation without re-fetching or re-processing.
- Final gif is byte/pixel-identical to pre-refactor.

## Test
- `tar_outdated()` after a config-only change touching viz parameters reports zero phase-1 / phase-2 invalidations.
- Snapshot final gif hash before and after; confirm equal.
- Manual: open `3_visualize.R` and confirm only rendering logic remains.
