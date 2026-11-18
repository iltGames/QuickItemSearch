# Quick Item Search options window

## Intent

Put search preferences within reach of the search window. Let players control how much history the addon keeps and which related results appear automatically.

## Approaches

- Open the existing WoW AddOns settings page from the search window. This gives both entry points one settings interface, but takes the player out of the search window while they adjust it.
- Open a compact options window alongside search. This keeps the results in view and lets the player see changes immediately. The user chose this approach and also wants the preferences reachable through WoW AddOns settings.

## Design

- Add an Options button to the search window that toggles the compact window. Close the compact window when the search window closes.
- Put history length and result section toggles in both options locations. Both read and write the same saved settings. Keep the existing hotkey and gear level controls in WoW AddOns settings.
- Offer Off, 5, 10, 20, and 50 recent searches, with 10 as the default. Reducing the limit immediately removes older entries beyond the new limit. Off clears saved history and stops recording until re-enabled. The history menu supports every offered limit.
- Show checkboxes for the automatic Quests, Dungeons, Gathering, Spells, Recipes, Emotes, Trainers, and Boss Drops sections. Enable them all by default. Item matches are always available. Apply checkbox changes immediately to the open search.
- Keep explicitly requested results available. For example, disabling Quests hides automatic quest matches and still allows `@quest namehere` to find that quest. Apply the same rule to other direct searches, including recipes requested with `craft` and loot requested with `@dungeon`.
- Preserve existing history and preferences on upgrade. The compact window and its controls should follow the addon's existing visual style. Leave exact placement and control sizing to implementation.

## Acceptance checks

- Open options from search and find the same search preferences under WoW AddOns. Changes made in either place persist after reload and appear in the other.
- Lower the history limit and confirm the oldest entries disappear. Choose Off and confirm searches stop accumulating. Re-enable history and confirm new searches are recorded.
- Disable Quests and Recipes. A regular search hides their automatic sections. A direct quest or recipe search still shows its requested results. Re-enable the sections to restore them.
