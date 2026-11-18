# Result context menus and quest chat links

This historical draft records ideas considered during design. See the changelog for the features included in each release.

## Intent

Right-click any actionable search result to see what it can do. Let players share a quest from search results or from the open quest's info view, and set a waypoint for an NPC or object when a verified location is available.

## Approaches

- Extend the addon's current quest popup to show actions appropriate to each result. It already anchors to result rows and supports paging through related quests. The user chose this approach.
- Use WoW's context menu for native styling and submenus. This would replace the quest popup and depend on the menu APIs available in WoW Forever.

## Design

- Items offer **Inspect** and **Link in chat**, and keep the list of quests that require the item. Spells and recipes offer **Inspect** and **Link in chat**. Quests offer **Open quest** and **Link in chat**. Dungeons offer **View loot**. Emotes offer **Perform emote**. Expandable result controls can offer **Expand** or **Collapse**. Quest objectives, section headings, and other informational rows stay informational.
- Open the quest menu by right-clicking a quest result or the quest title in its info view. Use the selected quest ID in both places. Insert the native quest link into the chat edit box when available. Otherwise, use a Questie-compatible reference with the quest name and ID. It appears as plain text for players without Questie. Open chat with the link ready to edit when needed. Sending remains a player action.
- Treat quest starter and turn-in NPCs and objects as actionable results. Offer **Set map waypoint** when QuestieDB supplies a valid spawn and WoW allows a waypoint on its map. When there are multiple valid locations, identify them by zone and coordinates and let the player choose. Setting a waypoint replaces WoW's current user waypoint. Contacts and trainer results can share their name or known location in chat. Trainer waypoints require a reliable match to an NPC and its location.
- Keep left-click, modifier-click, and keyboard behavior. Reuse the existing item loading and chat-link paths. Close the popup when its result goes away, including when scrolling reuses the row for another result.
- Add a **Result context menus** toggle, enabled by default, using shared controls in the search cog and WoW AddOns settings. Turning it off restores the original quest-item right-click menu and removes the new right-click actions. Both settings entry points use the same saved value.

## Acceptance checks

- Right-click an ordinary item, quest item, quest, dungeon, spell, recipe, and emote. Confirm the menu only shows applicable actions and that quest-item paging still works.
- Link the same quest from the result and the info title. Verify native and fallback text, open and closed chat edit boxes, and that neither action sends chat.
- Set a waypoint from a quest contact with valid coordinates. Try a contact with multiple locations and one with unavailable coordinates. Check that the correct map gets the waypoint and unavailable locations have no waypoint action.
- Confirm informational rows open no menu, a menu closes when its owner changes, and the toggle takes effect from both settings locations and persists across reload.
