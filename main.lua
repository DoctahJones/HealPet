local Addon = LibStub("LibDataBroker-1.1"):NewDataObject("HealPet", {
	icon = "Interface\\Icons\\spell_misc_petheal",
	label = "HealPet",
	text = "--",
	type     = "data source"
})

local self = CreateFrame("Frame")
local reviveOffCD = false
local hurtPets = 0
local updateEvery, elapsed = 1, 0
local initialUpdate, initialUpdateMax = 0, 2
local tooltip

self:RegisterEvent("ADDON_LOADED")
self:RegisterEvent("PLAYER_ALIVE")
self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
self:RegisterEvent("PET_JOURNAL_PETS_HEALED")

self:SetScript("OnEvent", function(self, event, ...)
  self[event](self, ...)
end)

self:SetScript("OnUpdate", function(self, elap)
	elapsed = elapsed + elap
	if elapsed < updateEvery then return end
	elapsed = 0
	
	if(not(initialUpdate > initialUpdateMax)) then
		--need to wait for c_petjournal to be loaded before getting initial number of hurt pets.
		if(initialUpdate == initialUpdateMax) then
			hurtPets = getNumberHurtPets()
			initialUpdate = initialUpdate + 1
		elseif (initialUpdate < initialUpdateMax) then
			initialUpdate = initialUpdate + 1
		end
	end
	if hurtPets == 0 then 
		Addon.text = string.format("|cff00ff000 hurt")
	else
		if reviveOffCD then 
			Addon.text = string.format("|cffff0000%d hurt", hurtPets)
		else
			local cdLeft = checkReviveCD()
			Addon.text = string.format("%ds", cdLeft)
			if cdLeft == 0 then
				reviveOffCD = true
			end
		end
	end
end)


function self:ADDON_LOADED(name)
  if name ~= "HealPet" then return end
end

function self:PLAYER_ALIVE()
	self:RegisterEvent("UPDATE_SUMMONPETS_ACTION")
end

function self:UPDATE_SUMMONPETS_ACTION()
	hurtPets = getNumberHurtPets()
end

function self:UNIT_SPELLCAST_SUCCEEDED(...)
	local unit, _, _, _, spellid = ...;
	if (unit == "player") and (spellid == 125439) then
		reviveOffCD = false
		hurtPets = 0
	end
end

function self:PET_JOURNAL_PETS_HEALED()
	hurtPets = getNumberHurtPets()
end

--Calculates and returns the cooldown in seconds remaining of the ReviveBattlePets spell. 
function checkReviveCD() 
	local start, duration = GetSpellCooldown(125439);
	if (start == 0) and (duration == 0) then
		return 0
	else 
		--local cdLeft = duration - (GetTime() - start)
		--return cdLeft
		return duration - (GetTime() - start)
	end
end

function getHurtPetList()
	clearPetFilters()
	local _, learntPets = C_PetJournal.GetNumPets()
	local t = {}
	for i=1, learntPets do
		local petID, _, _, customName, _, _, _, speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)
		local health, maxHealth = C_PetJournal.GetPetStats(petID)
		if health < maxHealth then
			tinsert(t, {(customName or speciesName), icon, health, maxHealth})
		end
	end
	return t
end

--Count the number of hurt pets in collection. Returns the number of hurt pets.
function getNumberHurtPets()
	clearPetFilters()
	local count = 0
	local _, learntPets = C_PetJournal.GetNumPets()
	for i=1, learntPets do
		local petID = C_PetJournal.GetPetInfoByIndex(i)
		local health, maxHealth = C_PetJournal.GetPetStats(petID)
		if health < maxHealth then
			count = count + 1
		end
	end
	return count
end

--Clears pet filters so that all pets owned by the player are listed.
function clearPetFilters()
	C_PetJournal.AddAllPetSourcesFilter()
	C_PetJournal.AddAllPetTypesFilter()
	C_PetJournal.ClearSearchFilter()
	C_PetJournal.SetFlagFilter(LE_PET_JOURNAL_FLAG_COLLECTED, true)
end

function Addon.OnTooltipShow(t)
	if not tooltip then tooltip = t end
	t:ClearLines()
	pets = getHurtPetList()
	t:AddLine("HealPet")
	t:AddLine(" ")
	local ICON_PATTERN_16 = "|T%s:16:16:0:0|t";
	for i = 1, #pets do
		t:AddLine(string.format("|T%s:16:16:0:0|t %s |cffff0000%s|cffffffff/%s", pets[i][2],  pets[i][1], pets[i][3], pets[i][4]))
	end
	t:AddLine("|cff00ff00Hint: Left-click to open pet journal.")
	t:Show()
end



function Addon.OnClick()
local button = GetMouseButtonClicked()
	if button == "LeftButton" then
			ToggleCollectionsJournal(2)
	end
	Addon.OnTooltipShow(tooltip)
end