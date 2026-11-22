-- PresentationTimeline: the ONE table of reveal / capture / card timings used by every client
-- module (CreatureRenderer, ThrowController, ClientMain). Presentation only: the server still owns
-- the authoritative catch deadline (Config.CatchDelay, unchanged) and never waits for clients.
-- Location: ReplicatedStorage > Shared > PresentationTimeline (ModuleScript)
--
-- Per throw:  PortalThrown -> flight (server t) -> local landing bounces (0.5 s) -> gate opens
--             PortalOpened (server: flight + 0.9) -> creature entrance (Entrance[r])
--             -> showcase (>= ShowcaseMin) -> server catch at CatchDelay[r] -> capture (Capture[r])
--             -> caught card (Card.enter + Card.hold + Card.travel), queued per player.

local Config = require(script.Parent.Config)

local T = {}

-- species entrance must END inside this window (seconds after PortalOpened)
T.Entrance = { Common = 1.5, Uncommon = 1.5, Rare = 1.4, Epic = 1.4, Legendary = 2.2, Mythical = 2.4, Secret = 1.9, Divine = 2.6 }
-- capture presentation after the server's collect event
T.Capture = { Common = 0.9, Uncommon = 1.0, Rare = 1.2, Epic = 1.3, Legendary = 1.6, Mythical = 1.8, Secret = 1.6, Divine = 2.0 }
T.CaptureAccent = 0.2      -- fraction of Capture[r] given to the species capture accent
T.ShowcaseMin = 0.8        -- readable full-silhouette hold between entrance and capture
T.LandBounce = 0.5         -- local orb bounce before the gate opens
T.GateOpen = 0.45
T.GateClose = 0.35
T.Card = { enter = 0.35, hold = 1.3, travel = 0.45, gap = 0.25 }
T.CardFallback = 3.0       -- if the capture visual never reports, show the card anyway
T.CameraTimeout = 14       -- hard cap on any follow-camera claim
-- THROW CUTSCENE: time between PortalThrown and the ball leaving the hand (you raise the portal,
-- it powers up, you throw). The rarer the creature inside, the longer and crazier it gets.
-- The server delays the portal opening by the same amount, so the reveal stays in sync.
-- (ThrowCinematic: Common/Uncommon = 2 shots, Rare/Epic = 3 shots, Legendary+ = 4 shots)
T.Windup = { Common = 1.4, Uncommon = 1.5, Rare = 1.9, Epic = 2.3, Legendary = 2.9, Mythical = 3.3, Secret = 3.3, Divine = 3.8 }

function T.WindupFor(rarity: string?): number
	return (rarity and T.Windup[rarity]) or 1.4
end

function T.CatchDelay(rarity: string): number
	return Config.CatchDelay[rarity] or 3
end

function T.EntranceFor(rarity: string): number
	return T.Entrance[rarity] or 1.5
end

function T.CaptureFor(rarity: string): number
	return T.Capture[rarity] or 1
end

function T.Showcase(rarity: string): number
	return T.CatchDelay(rarity) - T.EntranceFor(rarity)
end

-- gate closes shortly after the creature has fully stepped out
function T.GateCloseAfterOpen(rarity: string): number
	return T.EntranceFor(rarity) + 0.35
end

-- owner's follow camera stays on the reveal until the capture has finished
function T.FollowHoldAfterOpen(rarity: string): number
	return T.CatchDelay(rarity) + T.CaptureFor(rarity) + 0.4
end

-- delay from the Deposit event (fired with the collect) to the caught card
function T.CardDelay(rarity: string): number
	return T.CaptureFor(rarity) + 0.1
end

function T.CardTotal(): number
	return T.Card.enter + T.Card.hold + T.Card.travel + T.Card.gap
end

return T
