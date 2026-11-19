# Quick Item Search

## Change summaries

- After making a change, give the user enough technical detail to review it. For a bug fix, explain the root cause, how it produced the reported behavior, and how the fix addresses it. For other changes, explain how the implementation works. Reference the relevant files or functions, describe how you verified the change, and call out anything still unverified.

## Options

- When adding a result section or user-facing feature, add an on/off toggle for it in the same change. Expose the toggle in both the search window's cog menu and WoW's AddOns settings by reusing the shared controls in `CreateSearchPreferences` in `UI.lua`.
- Use the addon's existing saved settings so both menus stay in sync and the choice persists across reloads. Preserve the existing behavior for saved settings that predate the new toggle unless the requested feature specifies a different default.
- For an automatic result section, add it to `addon.automaticSections` in `Search.lua` and honor its setting when adding automatic matches. Keep direct searches for that section available. For example, disabling automatic Quests still allows `@quest namehere`.
- Verify that the toggle controls the intended section or feature, is available in both menus, and persists after reload.
