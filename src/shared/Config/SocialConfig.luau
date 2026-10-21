--!strict
-- SocialConfig: the Roblox group ("Crew") reward (docs/15 H1/H9, fair rules). GroupId = 0 turns
-- the whole reward and its noticeboard sign off until the owner creates the group and pastes its
-- numeric id here (the steps are in marketing/products.md). No external links are shown in-game;
-- the sign only offers Roblox's own GroupService:PromptJoinAsync prompt.
local SocialConfig = {
	GroupId = 548313786, -- "Brightwake Games" (was "Tame A Titan Official"; shared with TameATitan)
	BonusPercent = 0.10, -- flat +10% on the daily streak crate, group members only
	NoticeboardPosition = Vector3.new(-178, 5.8, -50), -- the harbour events board's centre
	CheckRange = 26, -- studs from the board where walking past rechecks membership
	CheckCooldown = 15, -- s between membership checks for one player
}

return SocialConfig
