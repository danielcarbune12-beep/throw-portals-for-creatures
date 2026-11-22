-- ModelKit: shared construction helpers for the hand-authored SpeciesModels (Volcano / Candy / Crystal).
-- Location: ReplicatedStorage > Shared > ModelKit (ModuleScript)
--
-- All sizes and positions are in creature units (multiplied by the rarity size `s`). Models face -Z,
-- ground is y = 0, +X is the creature's "side = 1". Every helper fills the standard rig channels that
-- CreatureAnimator drives: bodyEntry/body, headEntry/head, feet (+knee), ears, eyes, wings, arms,
-- tail, chains, groups, glows.

local K = {}
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local PI = math.pi
local MAT = Enum.Material
K.V3, K.CF, K.ANG, K.PI, K.MAT = V3, CF, ANG, PI, MAT

function K.C(h) return Color3.fromHex(h) end

function K.new(H, rig, s)
	local k = { H = H, rig = rig, s = s }
	rig.glows = rig.glows or {}

	function k.v(x, y, z) return V3(x, y, z) * s end
	function k.c(x, y, z) return CF(x * s, y * s, z * s) end
	-- scaled copy of a CFrame given in units
	function k.sc(cf) return cf - cf.Position + cf.Position * s end

	---------------------------------------------------------------- primitives (sizes in units, cf already scaled)
	function k.b(parent, name, x, y, z, col, cf, mat, tr, c1) return H.blk(rig, parent, name, V3(x, y, z) * s, col, cf, mat, tr, c1) end
	function k.w(parent, name, x, y, z, col, cf, mat, tr, c1) return H.wdg(rig, parent, name, V3(x, y, z) * s, col, cf, mat, tr, c1) end
	function k.tri(parent, name, thick, h, base, col, cf, mat, tr) H.tri(rig, parent, name, thick * s, h * s, base * s, col, cf, mat, tr) end
	function k.spike(parent, name, len, base, col, cf, mat, tr) H.spike(rig, parent, name, len * s, base * s, col, cf, mat, tr) end
	function k.crystal(parent, name, len, w, col, cf, mat, tr) H.crystal(rig, parent, name, len * s, w * s, col, cf, mat, tr) end
	function k.diamond(parent, name, len, w, thick, col, cf, mat, tr) H.diamond(rig, parent, name, len * s, w * s, thick * s, col, cf, mat, tr) end
	function k.pv(parent, name, cf) return H.pivot(rig, parent, name, cf) end

	-- jointed block: `center` is where the block sits, `pivot` (units, block-local) is the point it turns about
	function k.jb(parent, name, x, y, z, col, center, pivot, mat, tr)
		local c1 = CF(pivot.X * s, pivot.Y * s, pivot.Z * s)
		return H.blk(rig, parent, name, V3(x, y, z) * s, col, center * c1, mat, tr, c1)
	end

	-- straight bar between two points A, B (units, parent-local); cross-section w x (th or w).
	-- `up` must not be parallel to A->B (default +Z, right for bars lying in the XY plane).
	function k.bar(parent, name, A, B, w, col, mat, tr, up, th)
		local a, b = A * s, B * s
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b, up or Vector3.zAxis)
		return H.blk(rig, parent, name, V3(w * s, (th or w) * s, len + math.min(w, th or w) * s * 0.5), col, cf, mat, tr)
	end

	-- flat (approximately isosceles) membrane triangle in the parent's XY plane at depth z:
	-- apex point P, base corners B1, B2 (units, Vector3 with z used as depth)
	function k.mem(parent, name, P, B1, B2, thick, col, mat, tr)
		local M = (B1 + B2) / 2
		local h = (P - M).Magnitude
		local base = (B1 - B2).Magnitude
		if h < 0.05 or base < 0.05 then return end
		local d = (P - M).Unit
		local phi = math.atan2(-d.X, d.Y)
		local cf = CF(((P + M) / 2) * s) * ANG(0, 0, phi) * ANG(0, PI / 2, 0)
		H.tri(rig, parent, name, thick * s, h * s, base * s, col, cf, mat, tr)
	end

	-- ring of blocks in the parent's XY plane (faces -Z) around `center`
	function k.ring(parent, name, center, radius, count, radial, tangent, depth, col, mat, tr)
		for i = 0, count - 1 do
			local a = i / count * PI * 2
			local cf = center * CF(math.cos(a) * radius * s, math.sin(a) * radius * s, 0) * ANG(0, 0, a)
			H.blk(rig, parent, name, V3(radial, tangent, depth) * s, col, cf, mat, tr)
		end
	end

	---------------------------------------------------------------- rig roles
	function k.body(x, y, z, col, at, mat, tr)
		local e, p = k.b(rig.root, "Body", x, y, z, col, k.c(0, at, 0), mat, tr)
		rig.bodyEntry, rig.body = e, p
		rig.bodyRadius = k.v(x / 2, y / 2, z / 2)
		return p, e
	end

	-- head block centred at `center` (scaled CFrame, parent-local) turning about `pivot` (units, head-local)
	function k.head(parent, x, y, z, col, center, pivot, mat)
		local e, p = k.jb(parent, "Head", x, y, z, col, center, pivot or V3(0, -y * 0.4, z * 0.3), mat)
		rig.headEntry, rig.head = e, p
		rig.headRadius, rig.faceY = k.v(x / 2, y / 2, z / 2), 0
		return p, e
	end

	function k.glow(part, base, bright)
		table.insert(rig.glows, { part = part, base = base, bright = bright or base:Lerp(Color3.new(1, 1, 1), 0.6) })
	end

	-- glowing slit eye (Neon); roll > 0 lifts the +X end
	function k.eye(parent, x, y, z, w, h, col, roll)
		local e, p = k.b(parent, "Eye", w, h, 0.06, col, k.c(x, y, z) * ANG(0, 0, roll or 0), MAT.Neon)
		table.insert(rig.eyes, e)
		k.glow(p, col)
		return e, p
	end

	function k.ear(parent, side, cf, kind)
		local e, p = k.pv(parent, "EarPivot", cf)
		table.insert(rig.ears, { e = e, side = side, kind = kind or "cat" })
		return p, e
	end

	function k.wing(parent, side, cf, tier)
		local e, p = k.pv(parent, "WingPivot", cf)
		table.insert(rig.wings, { e = e, side = side, tier = tier or 1 })
		return p, e
	end

	function k.arm(parent, side, cf)
		local e, p = k.pv(parent, "ArmPivot", cf)
		table.insert(rig.arms, { e = e, side = side })
		return p, e
	end

	-- pivot that opens on pose.open (rotation `amt` radians about `axis` at open = 1)
	function k.opener(parent, name, cf, axis, amt)
		local e, p = k.pv(parent, name, cf)
		e.openAxis, e.openAmt = axis, amt
		H.group(rig, "open", e)
		return p, e
	end

	-- two-bone leg. Hip pivot at (x, y, z) in body-local units; bodyY = body centre height above ground.
	-- o.up = {w, h, d} upper block; o.w2, o.d2 lower block; o.paw = {w, h, d, zOff}; o.col, o.col2,
	-- o.pawCol, o.toes (count), o.toeCol, o.band (colour), o.bandY, o.hind, o.splay (radians, outward),
	-- o.lh (fixed lower length for legs that never reach the ground)
	function k.leg(body, name, bodyY, x, y, z, o)
		local side = x >= 0 and 1 or -1
		local splay = (o.splay or 0) * side
		local e, pv = k.pv(body, name, k.c(x, y, z) * ANG(0, 0, splay))
		local uh = o.up[2]
		k.b(pv, "Upper", o.up[1], uh + 0.1, o.up[3], o.col, k.c(0, -uh / 2 + 0.05, 0))
		local ph = o.paw[2]
		local lh = o.lh or math.max(0.2, bodyY + y - uh * math.cos(splay) - ph)
		local ke, knee = k.pv(pv, name .. "Knee", k.c(0, -uh, 0) * ANG(0, 0, -splay))
		k.b(knee, "Leg", o.w2, lh + 0.1, o.d2, o.col2 or o.col, k.c(0, -lh / 2, 0))
		if o.band then k.b(knee, "Band", o.w2 + 0.06, 0.16, o.d2 + 0.06, o.band, k.c(0, -(o.bandY or lh - 0.12), 0)) end
		local pz = o.paw[4] or -0.06
		k.b(knee, "Paw", o.paw[1], ph, o.paw[3], o.pawCol or o.col, k.c(0, -lh - ph / 2, pz))
		if o.toes and o.toes > 0 then
			local n, tw = o.toes, o.paw[1] / o.toes
			for t = 1, n do
				k.b(knee, "Toe", tw * 0.78, ph * 0.92, 0.26, o.toeCol or o.pawCol or o.col,
					k.c((t - (n + 1) / 2) * tw, -lh - ph * 0.5, pz - o.paw[3] / 2 - 0.06))
			end
		end
		e.knee, e.upperLen, e.kneeDir = ke, uh * s, o.hind and -1 or 1
		table.insert(rig.feet, e)
		return e, pv, knee, lh
	end

	-- generic wagging tail: segs = { {w, h, len, pitch, col, yaw, mat}, ... }, first joint at c0.
	-- Each segment turns about its front end and extends along +Z (negative pitch curls it upward).
	function k.tail(parent, c0, segs, name)
		local prev, prevLen = parent, 0
		for i, d in ipairs(segs) do
			local cf = ((i == 1) and c0 or k.c(0, 0, prevLen * 0.45)) * ANG(d[4] or 0, d[6] or 0, 0)
			local e, p = k.jb(prev, name or "TailSeg", d[1], d[2], d[3], d[5], cf * k.c(0, 0, d[3] / 2), V3(0, 0, -d[3] / 2), d[7])
			table.insert(rig.tail, e)
			prev, prevLen = p, d[3]
		end
		return prev, prevLen
	end

	-- animated chain (CreatureAnimator chain kinds: tentacle | spine | neck | trail | fan | fluke | plume)
	-- segs = { {w, h, len, col, pitch, yaw, mat, tr}, ... }; returns the chain record (parts in rec.parts)
	function k.chain(parent, c0, segs, meta)
		local rec = { name = meta.name or "Chain", entries = {}, parts = {} }
		for kk, vv in pairs(meta) do rec[kk] = vv end
		local prev, prevLen = parent, 0
		for i, d in ipairs(segs) do
			local cf = ((i == 1) and c0 or k.c(0, 0, prevLen * 0.46)) * ANG(d[5] or 0, d[6] or 0, 0)
			local e, p = k.jb(prev, rec.name, d[1], d[2], d[3], d[4], cf * k.c(0, 0, d[3] / 2), V3(0, 0, -d[3] / 2), d[7], d[8])
			table.insert(rec.entries, e)
			table.insert(rec.parts, p)
			prev, prevLen = p, d[3]
		end
		rec.n = #rec.entries
		table.insert(rig.chains, rec)
		return rec
	end

	-- bat / dragon wing built in the wing pivot's XY plane (outward = side * X).
	-- o.wrist = Vector2 (unsigned x, y), o.tips = { Vector2, ... } outer -> inner, o.bone, o.mem,
	-- o.boneW, o.memTr, o.memMat, o.cap (colour for the leading-edge cap)
	function k.batWing(pv, side, o)
		local function P(v2, z) return V3(v2.X * side, v2.Y, z or 0) end
		local O, W = V3(0, 0, 0), P(o.wrist)
		k.bar(pv, "WingArm", O, W, o.boneW or 0.3, o.bone)
		if o.cap then k.bar(pv, "WingCap", O + V3(0, 0.12, -0.05), W + V3(0, 0.12, -0.05), (o.boneW or 0.3) * 0.7, o.cap) end
		for i, t in ipairs(o.tips) do
			k.bar(pv, "Finger", W, P(t, 0.02), (o.boneW or 0.3) * 0.65, o.bone)
			if i > 1 then k.mem(pv, "Membrane", W + V3(0, 0, 0.06), P(o.tips[i - 1], 0.06), P(t, 0.06), 0.06, o.mem, o.memMat, o.memTr) end
		end
		-- inner panel: wrist -> innermost tip -> shoulder
		k.mem(pv, "Membrane", W + V3(0, 0, 0.06), P(o.tips[#o.tips], 0.06), O + V3(0, -0.2, 0.06), 0.06, o.mem, o.memMat, o.memTr)
	end

	-- fan of feather blades from the wing pivot (outward = side * X). o.feathers = { {angle, len, width, col, tipCol}, ... }
	-- angle 0 = straight out, + = up. Each blade gets a pointed tip.
	function k.featherWing(pv, side, o)
		for i, f in ipairs(o.feathers) do
			local a, L, wdt = f[1], f[2], f[3]
			local dir = V3(math.cos(a) * side, math.sin(a), 0)
			local z = (o.z or 0.04) * i
			local base = V3(0, 0, z) + dir * (o.root or 0.1)
			local tipStart = base + dir * L * 0.78
			k.bar(pv, "Feather", base, tipStart, wdt, f[4], o.mat, o.tr, V3(0, 0, 1), o.thick or 0.12)
			-- pointed tip: triangle continuing the blade
			k.mem(pv, "FeatherTip", base + dir * L, tipStart + V3(-dir.Y, dir.X, 0) * wdt * 0.5, tipStart - V3(-dir.Y, dir.X, 0) * wdt * 0.5,
				(o.thick or 0.12), f[5] or f[4], o.mat, o.tr)
		end
	end

	return k
end

return K
