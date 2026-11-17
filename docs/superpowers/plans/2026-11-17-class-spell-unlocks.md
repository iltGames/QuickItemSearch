# Class spell unlocks implementation plan

**Goal:** Find spells unlocked at an exact class level using the installed What's Training addon only.

**Architecture:** Query `WT_API.GetCatalog` at runtime. Keep existing spell-name searches independent. Use the search UI's existing asynchronous result callback while `LoadClass` resolves spell names. Never copy or persist provider data.

**Tech stack:** WoW Lua 5.1, optional What's Training public API.

**Design:** User selected an optional provider integration, matching existing source integrations, instead of bundled data. Accept `warrior 10`, `warlock 12`, and spell-prefixed equivalents. Show ranks and Trainer/Quest labels; quest tooltips show quest IDs and available names, areas, race restrictions and minimum levels. Preserve all race variants, selecting only variants at the searched level. Missing/incompatible providers produce a useful hint.

## Steps

- [x] Add failing search tests for provider absence, exact levels, class selection, race-specific quest levels, asynchronous loading/cancellation, and existing spell searches.
- [x] Implement lookup and tooltip helpers in SpellSearch.lua; route class-level searches before gear parsing in Search.lua.
- [x] Add tooltip rendering in UI.lua and optional dependency in the TOC. Document usage.
- [x] Run search and window suites, review the diff, and install the development copy.

## Review focus

Provider may be missing or older. Catalog names may load asynchronously. Quest variants may unlock at different levels. Queries for another class must not be filtered by the player's race. Cancelled searches must not overwrite newer results.

## Execution

Implement inline in the existing working tree to preserve current uncommitted work. Do not commit unrelated changes or copy What's Training files.

Validation: search, window, and unlock tests pass under Lua 5.1. Read-only integration check against the installed What's Training API and Camelot catalogs returned five warrior level 10 spells (three quest rewards) and three warlock level 12 trainer spells. Independent review found no actionable correctness issues. Tooltip tests cover named sources and ID fallbacks. In-game UI verification remains manual.
