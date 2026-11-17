# Class spell browsing implementation plan

**Goal:** Support class-wide spell sections in either word order for all nine classes, with optional What's Training enrichment and a plain spell fallback.

**Architecture:** Extend the existing class lookup to accept `spells warlock` and `warlock spell`. Generate class associations alongside existing spell names from local client SkillLineAbility class masks and class skill lines. Never copy or persist another addon's data. Merge optional runtime catalog metadata onto the full client class list, retaining spells absent from the provider. Preserve exact-level search behavior.

**Tech stack:** Lua 5.1, existing Node DB2 generator, optional What's Training catalog API.

## Tasks

- [x] Extend regression tests, observe failure for missing class browsing, and cover both word orders, all nine classes, absent and old providers, full quest variants, and async section refresh.
- [x] Extend the generator to decode class masks, including DB2 common values, and emit class IDs only. Verify known class spells remain correctly separated.
- [x] Add class browsing with sections, runtime enrichment, deterministic ordering and provider fallback. Keep existing exact-level lookups intact.
- [x] Document query forms and fallback behavior.
- [x] Verify full tests, installed provider integration and review; install development copy.

## Decisions

User explicitly requested fallback to plain spells without What's Training. Client-generated associations include no unlock or source metadata. Class sections sort known levels first, then name and ID; unknown levels follow. Every race-specific quest variant remains available in class browsing. Work stays inline in the existing dirty tree to preserve prior changes; no commits or publishes.

Validation: all three Lua 5.1 test suites pass. Generator regenerated successfully from build 70938 client DB2 files and the local hotfix cache, preserving all 2,711 existing names and adding only class associations. All nine classes passed runtime integration checks against the installed provider and plain fallback checks without it. Independent review found no actionable issues. Development files installed; source and deployed spell file hashes match. In-game UI verification remains manual.
