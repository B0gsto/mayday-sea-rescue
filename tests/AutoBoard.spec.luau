-- auto_board (2026-10-21): close and steady with room, they climb aboard; ramming knocks them back.
return function(t)
	local AutoBoard = t.load("src/shared/Ops/Board.luau")

	t.test("close, slow, level and with room: they climb aboard", function()
		t.expect(AutoBoard.ready(5, 3, 5, true)).toBe(true)
		t.expect(AutoBoard.ready(5, 3, 5, false)).toBe(false) -- full craft
		t.expect(AutoBoard.ready(AutoBoard.REACH + 1, 3, 5, true)).toBe(false) -- too far
		t.expect(AutoBoard.ready(5, AutoBoard.STEADY_SPEED + 1, 5, true)).toBe(false) -- moving
		t.expect(AutoBoard.ready(5, 3, AutoBoard.STEADY_TILT + 5, true)).toBe(false) -- big waves
	end)

	t.test("only a fast run on top of them is a bump", function()
		t.expect(AutoBoard.rammed(2, AutoBoard.RAM_SPEED + 1)).toBe(true)
		t.expect(AutoBoard.rammed(2, 3)).toBe(false)
		t.expect(AutoBoard.rammed(AutoBoard.CONTACT + 3, AutoBoard.RAM_SPEED + 5)).toBe(false)
	end)

	t.test("a mission casualty is the crew's until aboard; free-roam ones are anyone's", function()
		local list = AutoBoard.privateList({ 12, 345 })
		t.expect(AutoBoard.mayAct(list, 12)).toBe(true)
		t.expect(AutoBoard.mayAct(list, 345)).toBe(true)
		t.expect(AutoBoard.mayAct(list, 34)).toBe(false) -- a prefix of another id is not a match
		t.expect(AutoBoard.mayAct(list, 1)).toBe(false)
		t.expect(AutoBoard.mayAct(AutoBoard.privateList({}), 12)).toBe(false)
		t.expect(AutoBoard.mayAct(nil, 12)).toBe(true) -- free-roam / big call: public
	end)
end
