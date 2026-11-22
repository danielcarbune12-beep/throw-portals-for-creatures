# Skyforge HUD and expedition interface

Approved direction: HUD option 2 (Skyforge), icon family C (Relic enamel).
The primary menu contains only Pets, Shop, Expeditions and Settings.

| Destination | Secondary tools |
| --- | --- |
| Pets | Owned creatures, placement, storage, selling, Collection bestiary |
| Shop | Portals, Upgrades, Courtyard customization, Biome unlocks/travel |
| Expeditions | Biome carousel, owned-pet portraits, dispatch, return, relic journal |
| Settings | Presentation/accessibility, return home, authorized developer tools |

During normal play the HUD shows money, income and one Menu button. The active
expedition adds a small progress widget; it disappears after the return is claimed.
The Skyforge expedition drawer stays at the bottom and leaves the world visible.
Its diorama previews are native lightweight models; pet portraits use actual owned
creature models. Return times and payouts remain server-authoritative. Dispatching
and claiming require the player's table. From elsewhere, Go to table returns the
player home and walks toward the table without bypassing the server range check.

The four approved enamel icons use an uploaded transparent 2x2 atlas with UI
clipping, avoiding assumptions about Roblox's uploaded image resolution. Source:
`assets/ui/skyforge-menu-atlas.png`; Roblox image: `rbxassetid://102541518466565`.
The generated atlas is a project asset. The concept-sheet extras remain reference
art, not additional top-level navigation. Selection never changes mission balance.
