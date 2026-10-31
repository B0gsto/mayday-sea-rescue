-- selene: allow(undefined_variable)
-- _ik: foot-target IK for R15 blocky rigs (from TameATitan hero_core). require("_ik").stance(root, leftFoot, rightFoot)
local M = AnimKit.merge

-- ---------------------------------------------------------------------------------------------------------------
-- Foot-target IK. Measured R15 rig (blocky, HipHeight 2.192): hips sit 0.5 stud either side of the pelvis and
-- 0.2 below its centre; thigh (hip->knee) 0.9207, shin (knee->ankle) 1.0097, ankle joint 0.262 above the sole.
-- stance(root, left, right) returns the Root joint plus hip/knee/ankle for both legs so that each foot's contact
-- point sits exactly on a world target (HumanoidRootPart frame, floor at y = -3.1924), whatever Root pos/pitch/yaw/
-- roll is. Foot spec fields: x,z (where the flat foot's centre sits; default hip x, 0), h (contact height above the
-- floor, 0 = planted), p (foot pitch, +toes up), yaw, toe / heel (pivot on the ball / heel instead of the flat sole).
-- ---------------------------------------------------------------------------------------------------------------
local FLOORY, THIGH, SHIN, ANKH = -3.1924, 0.9207, 1.0097, 0.262

local function vadd(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function vsub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function vscale(a, s)
	return { a[1] * s, a[2] * s, a[3] * s }
end
local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function unit(a)
	local l = math.sqrt(dot(a, a))
	return { a[1] / l, a[2] / l, a[3] / l }
end
local function mmul(a, b)
	local o = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function mvec(m, v)
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end
local function mT(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
local function rotX(d)
	local c, s = math.cos(math.rad(d)), math.sin(math.rad(d))
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(d)
	local c, s = math.cos(math.rad(d)), math.sin(math.rad(d))
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(d)
	local c, s = math.cos(math.rad(d)), math.sin(math.rad(d))
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
-- CFrame.Angles(x, y, z) = Rx * Ry * Rz
local function euler(x, y, z)
	return mmul(rotX(x), mmul(rotY(y), rotZ(z)))
end
local function toEuler(R)
	local y = math.asin(math.clamp(R[3], -1, 1))
	local x = math.deg(math.atan2(-R[6], R[9]))
	local z = math.deg(math.atan2(-R[2], R[1]))
	return x, math.deg(y), z
end
local function r2(v)
	return math.floor(v * 100 + 0.5) / 100
end

-- one leg: sgn = -1 left, +1 right; root = { p = pelvis centre, R = pelvis rotation }
local function solveLeg(sgn, root, s)
	local hip = vadd(root.p, mvec(root.R, { sgn * 0.5, -0.2, 0 }))
	local Rf = mmul(rotY(s.yaw or -sgn * 6), rotX(s.p or 0))
	local cz = if s.toe then -0.5 elseif s.heel then 0.5 else 0
	local contact = { s.x or sgn * 0.55, FLOORY + (s.h or 0), (s.z or 0) + cz }
	local ankle = vsub(contact, mvec(Rf, { 0, -ANKH, cz }))
	local v = mvec(mT(root.R), vsub(ankle, hip))
	local d = math.sqrt(dot(v, v))
	local reach = THIGH + SHIN - 0.002
	local u = vscale(v, 1 / d)
	if d > reach then
		d = reach
	end
	d = math.max(d, 0.2)
	local pole = { sgn * (s.k or 0.12), 0, -1 }
	local w = unit(vsub(pole, vscale(u, dot(pole, u))))
	local ca = math.clamp((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d), -1, 1)
	local sa = math.sqrt(1 - ca * ca)
	local t = vadd(vscale(u, ca), vscale(w, sa))
	local sh = unit(vsub(vscale(u, d), vscale(t, THIGH)))
	local kdeg = -math.deg(math.acos(math.clamp(dot(t, sh), -1, 1)))
	local X = cross(u, w)
	local Y = vscale(t, -1)
	local Z = cross(X, Y)
	local R = { X[1], Y[1], Z[1], X[2], Y[2], Z[2], X[3], Y[3], Z[3] }
	local hx, hy, hz = toEuler(R)
	local chain = mmul(root.R, mmul(R, rotX(kdeg)))
	local ax, ay, az = toEuler(mmul(mT(chain), Rf))
	local side = if sgn < 0 then "Left" else "Right"
	local out = {}
	out[side .. "Hip"] = { x = r2(hx), y = r2(hy), z = r2(hz) }
	out[side .. "Knee"] = { x = r2(kdeg) }
	out[side .. "Ankle"] = { x = r2(ax), y = r2(ay), z = r2(az) }
	return out
end

-- root: AnimKit Root spec { pos = {x,y,z}, x, y, z }; lf / rf: foot specs (see above)
local function stance(root, lf, rf)
	local pos = root.pos or { 0, 0, 0 }
	local Rr = euler(root.x or 0, root.y or 0, root.z or 0)
	local centre = vadd({ pos[1], -1 + pos[2], pos[3] }, mvec(Rr, { 0, 0.2, 0 }))
	local r = { p = centre, R = Rr }
	return M({ Root = root }, solveLeg(-1, r, lf or {}), solveLeg(1, r, rf or {}))
end

-- shoulder (or hip) spec from parent-frame moves: twist about the limb's own axis, then swing forward, then raise
-- sideways (right side: +out raises outward; mirror the left with -out, -twist). Twist +90 on the right turns the elbow's
-- bend inward (hands on hips, folded arms, elbows-out overhead holds).
local function arm(fwd, out, twist)
	local x, y, z = toEuler(mmul(rotZ(out or 0), mmul(rotX(fwd or 0), rotY(twist or 0))))
	return { x = r2(x), y = r2(y), z = r2(z) }
end

return { stance = stance, arm = arm, FLOORY = FLOORY }
