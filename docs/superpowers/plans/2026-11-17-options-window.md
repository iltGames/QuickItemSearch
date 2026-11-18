# Search Options Implementation Plan

> For agentic workers, use superpowers:executing-plans to implement the steps below.

**Goal** Add a compact Options window and expose its search preferences in WoW AddOns settings.

**Architecture** Keep section filtering in Search.lua and history and shared controls in UI.lua. Both options surfaces use the same saved variables and control builder.

**Tech stack** WoW Lua and the existing Lua test harnesses.

**Spec** [Options window design](../specs/2026-11-17-options-window-design.md)

## Global constraints

Keep ten history entries by default and enable all automatic sections by default. Preserve explicit searches and item matches. Install the verified changes into QuickItemSearchDev.

## Review focus

- Filter quest results even when the provider finishes asynchronously.
- Keep a targeted recipe action available when Recipes is disabled.
- Make every retained history entry reachable without an over-tall menu.
- Trim old history immediately and suspend recording at zero.
- Reflect changes across both options surfaces and close the compact window with search.

## Search sections

- [x] Add cases to tests/search.lua and tests/quest-search.lua that disable automatic sections through saved settings and assert direct searches still return their matches. Run them and confirm that the filters are missing.
- [x] Define the ordered section names and addon.IsAutomaticSectionEnabled in Search.lua. Gate the supplemental section lookups in SectionResults while preserving requested groups and recipe matches derived from gathering.
- [x] Rerun both search suites and confirm the filters, direct searches, and asynchronous results pass.

## Options and history

- [x] Add coverage to tests/window.lua for options access, immediate query refresh, shared controls, and choosing 50, 5, and Off. Run the suite and confirm that the Options button is missing.
- [x] Implement history normalization, trimming, and bounded pages in UI.lua. Reuse the result popup navigation for history pages.
- [x] Build shared controls over the existing saved variables. Add the compact panel and its header button, and mount the same controls below the existing AddOns options.
- [x] Run every Lua test, check the diff, install the dev addon files, and verify the installed search and UI files.
