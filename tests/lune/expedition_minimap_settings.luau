local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/ExpeditionMiniMap.lua"):gsub("\r\n", "\n")
local function between(a, b)
	local first = assert(source:find(a, 1, true))
	return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end
local color = H.roblox.Color3.fromRGB
local updateStart = assert(source:find("function Mini.Update(", 1, true))
local code = between("local X0, X1, Z0, Z1", "\n\nlocal function corner")
	.. "\n"
	.. between("local function toMap(", "\nfunction Mini.SetPlan")
	.. "\nlocal Mini = {}\n"
	.. source:sub(updateStart)
local Mini = luau.load(code, {
	environment = setmetatable({
		UDim2 = H.roblox.UDim2,
		Color3 = H.roblox.Color3,
		Battle = H.require(H.SHARED .. "/ExpeditionBattle"),
		T = { Text = color(42, 33, 27), Gold = color(121, 81, 19), Danger = color(167, 48, 59) },
	}, { __index = _G }),
})()
local plan = {
	encounters = { { p = 0.4, name = "Sentry" } },
	theme = { body = color(100, 120, 90), accent = color(200, 180, 100) },
	pet = { name = "Mossbun" },
}
local monster = { frame = {}, stroke = {}, mark = {}, size = 15 }
local mm = {
	plan = plan,
	pet = {},
	petInner = {},
	count = {},
	monsters = { monster },
	log = {},
	hpFill = {},
	hpText = {},
	monBack = {},
	monText = {},
	monFill = {},
}
local state = { p = 0.2, kind = "walk", cleared = 0, text = "Scouting", hp = 80, maxHp = 100 }
Mini.Update(mm, state, 0.1)
H.check(mm.pet.Position.Y.Offset ~= 0, "default mini-map retains walking bob")
Mini.Update(mm, state, 0.1, { ReducedMotion = true })
local calm = mm.pet.Position
Mini.Update(mm, state, 0.9, { ReducedMotion = true })
H.check(mm.pet.Position == calm and mm.pet.Position.Y.Offset == 0, "Reduced Motion removes walking bob")
state.enc, state.phase, state.monHp, state.monMax = 1, 0.6, 90, 100
state.kind, state.beat = "fight", { who = "mon", dmg = 5 }
Mini.Update(mm, state, 0.9)
H.check(mm.petInner.BackgroundColor3 == color(255, 80, 70), "default mini-map retains hit flash")
H.check(monster.frame.Size.X.Offset > 15, "default fighting marker retains emphasis animation")
Mini.Update(mm, state, 0.9, { ReducedFlashes = true })
H.check(mm.petInner.BackgroundColor3 == color(70, 160, 255), "Reduced Flashes suppresses damage color flashes")
Mini.Update(mm, state, 0.9, { ReducedMotion = true })
H.check(
	monster.frame.Size.X.Offset == 15 and mm.petInner.BackgroundColor3 == color(70, 160, 255),
	"Reduced Motion uses steady fighting markers"
)
H.check(
	math.abs(mm.hpFill.Size.X.Scale - 0.8) < 0.00001
		and math.abs(mm.monFill.Size.X.Scale - 0.9) < 0.00001
		and mm.log.Text == "Scouting",
	"calm display preserves authoritative health and log"
)
state.beat = { who = "pet", dmg = 8 }
Mini.Update(mm, state, 0.9, { ReducedMotion = true })
local steadyAttack = mm.pet.Position
Mini.Update(mm, state, 1.1, { ReducedMotion = true })
H.check(mm.pet.Position == steadyAttack, "calm attack marker does not lunge")
Mini.Update(mm, state, 1.1, {})
H.check(mm.pet.Position ~= steadyAttack, "turning Reduced Motion off restores attack motion live")
state.beat, state.enc, state.p, state.kind = nil, nil, 0.8, "return"
Mini.Update(mm, state, 1.1, { ReducedMotion = true })
H.check(
	mm.pet.Position ~= calm and mm.monBack.Visible == false,
	"Reduced Motion keeps route progress and encounter transitions"
)
assert(H.summary() == 0, "Expedition mini-map settings regressions")
