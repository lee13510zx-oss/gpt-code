# koreastudy content integrity audit

- Generated at: 2026-06-22 14:43:02
- Content integrity score: 100 / 100
- Target: at least 85 points
- Catalog: 3 school levels, 49 subjects, 43 profiles
- Simulation: 500000 content combinations, 0 failures
- Result: PASS

## Checks

|Check|Points|Result|Evidence|
|---|---:|---|---|
|school catalog breadth|8|PASS|3 school levels, 49 subjects|
|curriculum coverage|6|PASS|2022, 2015|
|direct subject profile coverage|8|PASS|43/49 subjects with direct profiles|
|fallback profile safety|7|PASS|fallback profile fields|
|profile field completeness|8|PASS|44 domains, 44 focus, 44 summaries, 44 formulas|
|unit seed breadth|8|PASS|57 unit/array seeds|
|question category coverage|8|PASS|4/4 categories|
|question template richness|7|PASS|12 templates with difficulty/prompt/answer|
|question format coverage|5|PASS|5/5 formats|
|generated material sections|7|PASS|goal, table, mindmap, questions|
|copyright-safe data posture|6|PASS|policy and governance warnings|
|user input guarded into output|5|PASS|80 escapeHtml references|
|self-check content checks|4|PASS|runtime self-check data keys|
|content combination simulation|13|PASS|500000 scenarios, 0 failures|

## Failed checks

- No failed content integrity checks.

## Limits

- This no-cost audit checks internal data breadth and generation consistency, not official textbook correctness.
- Copyright-restricted textbooks, commercial worksheets, and full mock exam originals are still deferred until rights are approved.