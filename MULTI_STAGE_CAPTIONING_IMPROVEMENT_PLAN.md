# Multi-Stage Captioning Improvement Plan

## Scope

This review compares `temp/target.jpg` with `temp/target.json` and the current multi-stage implementation in:

- `assets/prompts/vision_enumerate.txt`
- `assets/prompts/element_enrich.txt`
- `lib/features/structured_captioning/data/repositories/structured_caption_repository.dart`
- `lib/features/structured_captioning/data/utils/caption_hardening.dart`

The target contains 24 elements, exactly the current prompt cap. Some duplicate-pruning code now present in the repository should have removed the repeated staircase, so the artifact may predate the latest implementation. Reproduce it from the current worktree before treating every output defect as current behavior.

## First-Run Flaws

### 1. Coverage is incomplete despite using the full element budget

The image is a dense cutaway interior with several distinct living, sleeping, dining, and work zones. The JSON spends all 24 slots but omits or reduces many visually important subjects:

- The upper-right white sofa, middle-left pink sofa, middle-right orange sofa, and lower-right blue sofa are absent as complete seating elements. Two are represented only as a cushion.
- Multiple chairs, dining tables, coffee tables, desks, computers/monitors, televisions, consoles, cabinets, shelves, windows, stair flights, and wall-art groups are missing.
- Only one framed-picture element represents many separated picture clusters.
- Only one window and one door are represented despite several distinct zones.
- The high-level description, `Multi-level pink interior with plants, furniture, and stairs`, is too generic to preserve the cutaway composition or the scene's distinct functional zones.

This is primarily an enumeration failure. Enrichment cannot recover an object kind that pass 1 omitted.

### 2. Duplicate and competing elements consume slots

Several final elements share exactly the same bbox:

- Table, chair, and plate: `[790, 250, 960, 460]`
- Bookshelf and books: `[510, 530, 650, 840]`
- Staircase appears twice at `[170, 490, 330, 580]`

The current duplicate filter only removes boxes with IoU above `0.90` when the names are also lexically similar. It intentionally keeps same-box elements with different names, so table/chair/plate and bookshelf/books survive even though the boxes do not localize separate subjects. These collisions waste at least four slots and produce ambiguous crops.

The quality report is built after duplicate pruning, so it cannot accurately report duplicates already removed. Duplicate-box health issues are warnings raised after enrichment, when the expensive calls have already happened.

### 3. Several bboxes are not tight enough for isolated enrichment

Examples include:

- The rug bbox `[670, 100, 990, 800]` covers much of the lower floor and multiple furniture groups.
- The framed-picture bbox `[30, 120, 140, 500]` covers a broad wall strip rather than one picture or one coherent cluster.
- Several plant boxes include furniture, decor, or multiple unrelated plant zones.
- The shared table/chair/plate bbox cannot be a tight box for all three subjects.
- The desk bbox captures mostly a narrow desktop strip, losing the monitor, legs, and chair needed to identify the workstation.

The current gate rejects only exact full-canvas and greater-than-80%-canvas boxes. A badly localized box covering 20-30% of a dense image still passes and is enriched.

### 4. Enrichment amplifies bad localization

The enriched descriptions expose crop contamination and identity drift:

- A sofa is reduced to an `Orange sofa cushion`.
- A table crop mentions a neighboring pink chair.
- A plant crop describes three nearby pots rather than one localized element.
- The bookshelf and books receive separate descriptions from the same crop.
- The table, chair, and plate receive separate descriptions from the same crop.

The sanity check only rejects a short list of whole-scene phrases. It does not reject same-box collisions, identity changes, neighboring subjects, unsupported material claims, or descriptions outside the requested 30-60 words.

### 5. Hallucinations and over-specific claims remain

Visible examples include:

- `Orange cat feet at base` in the bed description.
- A `black cat with a white patch` where no clear black cat is visible in the supplied image.
- Photographic texture claims such as worn edges, glossy surfaces, wood grain, plush texture, and visible soil that are not reliably observable in this flat illustration.
- A huge lower-floor crop described as one uniform orange rug.

The 30-60 word minimum encourages padding when a small stylized object has few observable attributes. The parser accepts any non-empty description, so the requested range is not actually enforced.

### 6. Background and object contracts are inconsistent

The background contains `multiple staircases` while staircases are also object elements, violating the prompt's shell-only rule. The background also compresses materially different levels into `yellow floor` and `wooden flooring in lower level`, reducing compositional accuracy.

`captionHealthIssues` only warns when more than one object name appears in the background. A single clear violation is ignored, and simple substring matching misses singular/plural variants.

### 7. The prompt contract is internally noisy

`vision_enumerate.txt` repeats the same grouping, coverage, localization, and cap rules in several sections. It also asks for:

- every distinct kind once;
- separate groups for the same kind in different zones;
- up to four groups per repeated noun;
- one element per coherent subject;
- 12-18 elements as a target;
- a hard cap of 24.

The intended design supplied for this mode says a hard cap of 30, while the current prompt and tests enforce 24. The unresolved cap and competing grouping instructions make slot allocation less predictable.

### 8. Debug output is insufficient to locate failures

`_saveMultiStageDebugArtifacts` claims to save per-element enrich artifacts and failures, but currently writes only the parsed enumerate analysis and quality report. Its `enumeratePrompt` and `enrichFailures` parameters are unused. Crops, enrich prompts, raw enrich responses, rejection reasons, and merge outcomes are not retained.

Without those artifacts it is impossible to distinguish:

- a wrong enumerate name;
- a wrong enumerate bbox;
- a correct crop with a bad enrich response;
- a rejected enrich response that fell back to the terse text;
- a later SAM bbox change that no longer matches the crop used for enrichment.

## Improvement Plan

Each phase should leave single-shot mode unchanged and keep multi-stage failures isolated per element.

### Phase 0: Establish a Reproducible Baseline

**Goal:** Determine which defects still exist in the current worktree.

- Run `temp/target.jpg` again with multi-stage and debug mode enabled.
- Save the raw enumerate response, normalized pre-enrich analysis, VLM bbox overlay, final bbox overlay, and final caption.
- Extend existing debug output to save one record per enrich attempt: element index/name, bbox, crop path or retained crop, prompt, raw response, accepted/fallback status, and rejection reason.
- Include duplicate objects removed before the quality report is built.
- Record provider/model, bbox order, SAM enabled state, and prompt version with the run.

**Acceptance criteria:** A reviewer can trace every final description back to one enumerate element and one crop without rerunning the model.

### Phase 1: Simplify and Align the Enumeration Contract

**Goal:** Make pass 1 allocate slots to broad scene coverage before repeated decor.

- Choose one hard cap and use it consistently in the feature description, prompt, and tests. Use 30 if the supplied multi-stage contract is authoritative.
- Replace repeated prose with one ordered algorithm:
  1. Split the image into visible functional/spatial zones.
  2. List major furniture, architecture, electronics, animals, and text in each zone.
  3. Group repeated decor within a zone.
  4. Merge or drop low-salience decor only if the cap is reached.
- State that a whole furniture object wins over its parts: `sofa`, not separate sofa/cushion elements; `bookshelf with books`, not identical-box bookshelf and books elements.
- Require zone-qualified names for repeated categories, such as `upper-left plants` and `lower-right plants`, while retaining a short noun identity in `desc`.
- Keep `background` to walls, floors, ceiling/open cutaway shell, and ambient lighting. Do not apply the fragile rule that no object noun may ever occur there; instead explicitly ban object entries from being duplicated as background subjects.
- Remove the conflicting 12-18 target if the actual contract permits up to 30.

**Acceptance criteria for the target image:** The enumerate output includes all major sofas/seating zones, tables/desks, screens/electronics, stair flights, shelf/cabinet zones, door/window zones, wall-art groups, and plant groups before minor dishes or cushions consume remaining slots.

### Phase 2: Reject Bad Enumeration Before Fan-Out

**Goal:** Do not spend up to 30 enrich calls on structurally bad input.

- Run a deterministic pre-enrich gate after parsing and bbox normalization.
- Reject exact duplicate bboxes, regardless of name. A tight localization contract cannot validly assign one exact box to table, chair, and plate.
- Reject same-name/high-IoU duplicates and preserve the existing normalized-name check for near-duplicates.
- Reject null, degenerate, out-of-range, full-canvas, and near-full-canvas boxes.
- Flag suspiciously broad boxes when a single non-group element occupies a large area. Start with a conservative threshold derived from baseline data rather than an object-specific rules engine.
- Enforce the cap in code by truncating only after ranking major objects before repeated decor, or preferably reject an over-cap response and retry.
- If the gate fails, perform at most one re-enumeration with a compact defect list such as `duplicate bbox for table/chair/plate` and `missing major seating categories`. If the retry still fails, use the better of the two parsed outputs or fail the image before enrichment.
- Build the quality report from the original parsed list, then record every prune/reject decision.

**Acceptance criteria:** No enrich calls start when the enumerate result contains exact bbox collisions or exceeds the cap. The target run has no duplicate final bboxes caused by pass 1.

### Phase 3: Make Enrichment Conservative

**Goal:** Add useful visible detail without changing the enumerated identity.

- Change the description target from a mandatory 30-60 words to a bounded maximum with an explicit stop rule, for example 12-40 words and `use fewer words when the crop does not support more detail`.
- Tell the model to begin with the supplied identity and never replace a whole object with a visible part. A sofa crop may mention cushions, but must remain a sofa description.
- For illustrations, ban unsupported tactile/material claims unless visually explicit. Prefer color, shape, arrangement, and drawn details.
- Add a small configurable-in-code crop margin only if baseline crops show edge truncation. Keep the margin fixed and minimal; do not add a user setting.
- Validate enrich responses deterministically: valid JSON object, non-empty `desc`, reasonable word count, no whole-scene phrases, and `text` only for text elements.
- Keep the terse enumerate description on rejection, as the current implementation does.
- Do not attempt semantic auto-repair with another per-element call until the simpler prompt and pre-enrich bbox gate have been measured.

**Acceptance criteria:** The target output contains no invented cats, no whole-object-to-part identity changes, and no separate descriptions generated from one exact crop.

### Phase 4: Verify Merge, SAM, and Final Consistency

**Goal:** Ensure the description, bbox, and palette refer to the same region.

- Record both the bbox used for enrichment and the final SAM-selected bbox.
- Measure IoU between them. Warn when SAM materially changes a box after enrichment.
- If material post-enrich drift is common, move SAM refinement for eligible single objects before enrichment and reuse those detections in the shared tail. Do not change sequencing unless the debug evidence demonstrates this mismatch.
- Run the final duplicate-box and cap checks as hard invariants, not log-only warnings.
- Warn on the first clear background/object duplication rather than only when multiple names match.

**Acceptance criteria:** Every final element can be associated with the crop that produced its description, and no final invariant violation is silently shipped.

### Phase 5: Add Focused Regression Checks

**Goal:** Prevent this failure shape without building a large evaluation framework.

- Add one unit fixture based on the defective enumerate structure to verify exact-box collisions are rejected before enrichment.
- Add one test that a sofa and its cushion with the same bbox resolve to the whole sofa or trigger re-enumeration.
- Add one test that the element cap is identical in prompt expectations and runtime validation.
- Add one test for enrich fallback when identity/sanity validation fails.
- Add one debug-artifact test proving failure reasons and raw enrich responses are persisted in debug mode.
- Maintain a small manual benchmark of 5-10 dense images. Track: major-kind recall, duplicate bbox count, hallucinated element count, enrich fallback count, and average calls per successful image.

**Acceptance criteria:** `temp/target.jpg` improves major-kind coverage, has zero exact duplicate bboxes, zero obvious hallucinated animals, and no broad mixed-subject crop described as one object.

## Recommended Order

1. Phase 0: capture a trustworthy current baseline.
2. Phase 2: stop invalid enumeration before costly fan-out.
3. Phase 1: simplify the prompt and align the cap.
4. Phase 3: reduce enrichment hallucination and identity drift.
5. Phase 4 only if bbox drift is demonstrated.
6. Phase 5 alongside each behavioral change.

## Deliberately Deferred

- No third always-on VLM pass. One bounded enumerate retry is enough until measurements show otherwise.
- No object ontology, embedding-based deduplicator, or model-specific prompt configuration.
- No per-provider concurrency changes; serial local MLX and remote width four are not implicated by this run.
- No single-shot tail rewrite unless SAM drift is measured.
