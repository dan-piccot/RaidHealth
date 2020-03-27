raidhealth = { }
local haveMage = false
local havePriest = false
local haveDruid = false
local numPaladins = 0
local playerList = {}
local resourceTimer = 0
local buffTimer = 0
local buffUpdateDelay = 3
local resourceUpdateDelay = 1
local healerList = {}
local RH_Popup
RaidHealth_SavedPresets = {}
RaidHealth_BlockList = {}

local meleeBuffs = { Priest = {"Prayer of Fortitude|Power Word: Fortitude"},
                    Paladin = {"Greater Blessing of Salvation|Blessing of Salvation","Greater Blessing of Light|Blessing of Light","Greater Blessing of Might|Blessing of Might","Greater Blessing of Kings|Blessing of Kings"},
                    Druid = {"Gift of the Wild|Mark of the Wild"},
                    Mage = {}}
local tankBuffs = { Priest = {"Prayer of Fortitude|Power Word: Fortitude"},
                    Paladin = {"Greater Blessing of Light|Blessing of Light","Greater Blessing of Might|Blessing of Might","Greater Blessing of Kings|Blessing of Kings"},
                    Druid = {"Gift of the Wild|Mark of the Wild"},
                    Mage = {}}
local rangedBuffs = { Priest = {"Prayer of Fortitude|Power Word: Fortitude","Prayer of Spirit|Divine Spirit"},
                    Paladin = {"Greater Blessing of Salvation|Blessing of Salvation","Greater Blessing of Light|Blessing of Light","Greater Blessing of Wisdom|Blessing of Wisdom","Greater Blessing of Kings|Blessing of Kings"},
                    Druid = {"Gift of the Wild|Mark of the Wild"},
                    Mage = {"Arcane Brilliance|Arcane Intellect"}}

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function checkRaidBuffs()
	raidhealth_checkRaidClasses()
	if IsInRaid() then
		playerList = {}
		local players = GetNumGroupMembers()
        for groupindex = 1,players do
            local id = select(3, UnitClass("raid"..groupindex))
            local isOnline = select(8,GetRaidRosterInfo(groupindex))
            if isOnline == true then
				local isMT = select(10, GetRaidRosterInfo(groupindex))
				if id == 11 then -- druids: always ranged, unless in bear OR set as a tank then tank, unless in cat then melee
					local s
					for i = 1,40,1 do
						s = UnitBuff("raid"..groupindex,i)
						if (s == "Dire Bear Form") or (s == "Cat Form") then
							break;
						end
					end
					if (isMT == "MAINTANK") or (s == "Dire Bear Form") then
						raidhealth_testBuffs("raid"..groupindex, tankBuffs)
					elseif s == "Cat Form" then
						raidhealth_testBuffs("raid"..groupindex, meleeBuffs)
					else
						raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
					end
				elseif id == 3 then -- hunters: always ranged
					raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
				elseif id == 8 then -- mages: always ranged
					raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
				elseif id == 2 then -- paladins: always ranged, unless set as a tank (doesn't work for ret)
					if isMT == "MAINTANK" then
						raidhealth_testBuffs("raid"..groupindex, tankBuffs)
					else
						raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
					end
				elseif id == 5 then -- priests: always ranged
					raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
				elseif id == 4 then -- rogues: always melee
					raidhealth_testBuffs("raid"..groupindex, meleeBuffs)
				elseif id == 7 then -- shaman: always ranged (doesn't work for enhance or elemental)
					raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
				elseif id == 9 then -- warlocks: always ranged
					raidhealth_testBuffs("raid"..groupindex, rangedBuffs)
				elseif id == 1 then -- warriors: always melee, unless in defensive stance OR set as a tank
					local s
					for i = 1,40,1 do
						s = UnitBuff("raid"..groupindex,i)
						if s == "Defensive Stance" then
							break;
						end
					end
					if (isMT == "MAINTANK") or (s == "Defensive Stance") then
						raidhealth_testBuffs("raid"..groupindex, tankBuffs)
					else
						raidhealth_testBuffs("raid"..groupindex, meleeBuffs)
					end
				end
			end
		end
	end
	raidhealth_UpdateBuffs()
end

function raidhealth_testBuffs(player, role)	
	local s,playername
	s= UnitBuff(player,1)
	playername = UnitName(player)
	local playerObject = {MissingBuffs = {}, TotalBuffs = {}, TotalPaladinBuffs = 0, MissingPaladinBuffs =0}
	--Loop Through Player Buffs
	for i=1,40,1 do
		s= UnitBuff(player,i)
		if not s then
			break;
		end
		--Check if Player is supposed to Have buff
		for class,buffs in pairs(role) do		
			for index,buff in pairs(buffs) do			
				if(s == RH_mysplit(buff,"|")[1] or s == RH_mysplit(buff,"|")[2]) then		
					if (class=="Paladin") then
						playerObject["TotalPaladinBuffs"] = playerObject["TotalPaladinBuffs"] + 1
					elseif (class=="Mage" and haveMage or class=="Priest" and havePriest or class=="Druid" and haveDruid)	then
						table.insert(playerObject["TotalBuffs"],buff)
					end
				end
			end			
		end				
	end
	--Check for Missing Buffs
	for class,buffs in pairs(role) do		
		if (class=="Mage" and haveMage or class=="Priest" and havePriest or class=="Druid" and haveDruid) then		
			for index,buff in pairs(buffs) do					
				if(not RH_contains(playerObject["TotalBuffs"],buff)) then										
					table.insert(playerObject["MissingBuffs"],buff)
				end
			end		
		end	
	end	
	--Update Missing Paladin Buffs
	if (math.min(#role["Paladin"],numPaladins) > playerObject["TotalPaladinBuffs"] ) then
		playerObject["MissingPaladinBuffs"] = math.min(#role["Paladin"],numPaladins) - playerObject["TotalPaladinBuffs"] 
	end
	playerList[playername] = playerObject
end

function raidhealth_checkRaidClasses()
    if IsInRaid() then
        local players = GetNumGroupMembers()
        numPaladins = 0
        haveMage = false
        havePriest = false
        haveDruid = false
        for groupindex = 1,players do
            local id = select(3, UnitClass("raid"..groupindex))
            local isOnline = select(8,GetRaidRosterInfo(groupindex))
            if isOnline == true then
                if id == 2 then
                    numPaladins = numPaladins + 1
                elseif id == 5 then
                    havePriest = true
                elseif id == 11 then
                    haveDruid = true
                elseif id == 8 then
                    haveMage = true
                end
            end
        end
    end
end

local function removeAll(tbl, val)
	for i, v in ipairs(tbl) do
		if v == val then
			table.remove(tbl, i)
		end
	end
end

function raidhealth:OnEvent(event, something, arg1)			
	if (event == "UNIT_POWER_UPDATE" or event == "UNIT_HEALTH" or event == "UNIT_AURA") and time() - resourceTimer > resourceUpdateDelay then
		resourceTimer = time()
		raidhealth.updateData()
		if time() - buffTimer > buffUpdateDelay then		
			buffTimer = time()
			checkRaidBuffs()
		end
	end
end

function raidhealth_UpdateHealth(value, maxVal)
	RH_HealthBar:SetMinMaxValues(0, maxVal)
	RH_HealthBar:SetValue(value)
	RH_HealthBar.title:SetText( string.format("%.0f%%", (100*(value/maxVal))));
end


function raidhealth_UpdateMana(value,maxVal)
	RH_ManaBar:SetMinMaxValues(0, maxVal)
	RH_ManaBar:SetValue(value)
	RH_ManaBar.title:SetText( string.format("%.0f%%", (100*(value/maxVal))));
end

function raidhealth_UpdateHealerMana(value,maxVal)
	RH_HealerManaBar:SetMinMaxValues(0, maxVal)
	RH_HealerManaBar:SetValue(value)
	RH_HealerManaBar.title:SetText( string.format("%.0f%%", (100*(value/maxVal))));
end

function raidhealth_UpdateBuffs()
    local value = 0
    local maxVal = 0
    for player,buffTable in pairs(playerList) do
        for buffType,buffs in pairs(buffTable) do
            if buffType == "MissingBuffs" then
                maxVal = maxVal + #buffs
            elseif buffType == "TotalBuffs" then
                value = value + #buffs
                maxVal = maxVal + #buffs
			elseif buffType == "TotalPaladinBuffs" then
				value = value + buffs
                maxVal = maxVal + buffs
			elseif buffType == "MissingPaladinBuffs" then				
                maxVal = maxVal + buffs
			end
        end
    end
    RH_BuffBar:SetMinMaxValues(0, maxVal)
    RH_BuffBar:SetValue(value)
    RH_BuffBar.title:SetText( string.format("%.0f%%", (100*(value/maxVal))));
end

function raidhealth:updateData(msg)
	if IsInRaid() then
		local players = GetNumGroupMembers()
		local healerTotal, healerTotalMax = 0, 0
		local healthTotal, healthTotalMax = 0, 0
		local manaTotal, manaTotalMax = 0, 0
		healerList = {}
		for groupindex = 1,players do
			local id = select(3, UnitClass("raid"..groupindex))
			local isOnline = select(8,GetRaidRosterInfo(groupindex))
			if isOnline == true then
				local ignoreMana = false
				local ignoreHealerMana = false
				for i = 1,40,1 do
					s = UnitBuff("raid"..groupindex,i)
					if (s == "Dire Bear Form") or (s == "Cat Form") then
						ignoreMana = true
						ignoreHealerMana = true
					end
					if (s == "Moonkin Form") or (s == "Shadowform") then
						ignoreHealerMana = true
					end
				end
				if (id == 2 or id == 5 or id == 11 or id == 7) and (has_value(RaidHealth_BlockList,string.lower(UnitName("raid"..groupindex,0))) == false) and (not ignoreHealerMana) then
					healerTotal = healerTotal + UnitPower("raid"..groupindex,0)
					healerTotalMax = healerTotalMax + UnitPowerMax("raid"..groupindex,0)
					local healerName = select(1, UnitName("raid"..groupindex))
					local healerObject = {Name = "", Power = 0, PowerMax = 0}
					healerObject["Name"] = healerName
					healerObject["Power"] = UnitPower("raid"..groupindex,0)
					healerObject["PowerMax"] = UnitPowerMax("raid"..groupindex,0)
					table.insert(healerList, healerObject)
				end
				healthTotal = healthTotal + UnitHealth("raid"..groupindex,0)
				healthTotalMax = healthTotalMax + UnitHealthMax("raid"..groupindex,0)
				if (not ignoreMana) then
                    manaTotal = manaTotal + UnitPower("raid"..groupindex,0)
                    manaTotalMax = manaTotalMax + UnitPowerMax("raid"..groupindex,0)
                end
			end
		end
		local healerOutput = string.format("%.0f%%", (100*(healerTotal/healerTotalMax)))
		local healthOutput = string.format("%.0f%%", (100*(healthTotal/healthTotalMax)))
		local manaOutput = string.format("%.0f%%", (100*(manaTotal/manaTotalMax)))
		raidhealth_UpdateHealth(healthTotal, healthTotalMax)
		raidhealth_UpdateMana(manaTotal,manaTotalMax)
		raidhealth_UpdateHealerMana(healerTotal,healerTotalMax)
	end
end

local function slashsettings(msg, editBox)
	local command = {}
	for i in string.gmatch(msg, "%S+") do
		table.insert(command, i)
	end
	if not command[1] then
		print("DISPLAY HELP")
	elseif string.lower(command[1]) == "add" then
		if not command[2] then
			print("Missing second argument for player")
		else
			print("Adding " .. string.lower(command[2]) .. " to healer block list")
			table.insert(RaidHealth_BlockList, string.lower(command[2]))
		end
	elseif string.lower(command[1]) == "remove" then
		if not command[2] then
			print("Missing second argument for player")
		elseif has_value(RaidHealth_BlockList, string.lower(command[2])) then
			print("Removing " .. string.lower(command[2]) .. " from healer block list")
			removeAll(RaidHealth_BlockList, string.lower(command[2]))
		else
			print("Player is not currently in block list")
		end
	elseif string.lower(command[1]) == "blocklist" then
		print(table.concat(RaidHealth_BlockList,", "))
	else
		print("INVALID COMMAND")
	end
end

function raidhealth:onLoad()
	print("RaidHealth Loaded")
	RH_MainFrame:RegisterEvent("UNIT_POWER_UPDATE")
	RH_MainFrame:RegisterEvent("UNIT_HEALTH")
	RH_MainFrame:RegisterEvent("UNIT_AURA")
	RH_MainFrame:SetScript("OnEvent", raidhealth.OnEvent)
	SLASH_RAIDHEALTH1 = "/rh"
	SlashCmdList["RAIDHEALTH"] = slashsettings	
	raidhealth.generateUI()
end

function RH_ShowPopup(bar)
	RH_Popup:SetPoint("TOP", bar, "TOP", 200, -20)
	RH_Popup:SetSize(200,#healerList*20 + 20)
	for i = 1,#healerList,1 do
		RH_Popup["textline"..i]:SetText(healerList[i].Name)
		RH_Popup["textline"..i]:Show()
		RH_Popup["textlineP"..i]:SetText(healerList[i].Name)
		RH_Popup["textlineP"..i]:Show()
		RH_Popup["textlineP"..i]:SetText( string.format("%.0f%%", (100*(healerList[i].Power/healerList[i].PowerMax))));
	end
	RH_Popup:Show()
end

function RH_HidePopup()
	RH_Popup:Hide()
	
	for i = 1,15,1 do		
		RH_Popup["textline"..i]:Hide()		
		RH_Popup["textlineP"..i]:Hide()
	end
end

function raidhealth:generateUI()
	local paddingH = 5
	RH_HealthBar.title = RH_HealthBar:CreateFontString(nil, "OVERLAY")
	RH_HealthBar.title:SetFontObject("GameFontHighlight", 24)
	RH_HealthBar.title:SetPoint("RIGHT", RH_HealthBar, "RIGHT", -paddingH, 0)

	RH_HealthBar.header = RH_HealthBar:CreateFontString(nil, "OVERLAY")
	RH_HealthBar.header:SetFontObject("GameFontHighlight", 24)
	RH_HealthBar.header:SetPoint("LEFT", RH_HealthBar, "LEFT",paddingH, 0)	
	RH_HealthBar.header:SetText("Overall Health");

	RH_HealerManaBar.title = RH_HealerManaBar:CreateFontString(nil, "OVERLAY")
	RH_HealerManaBar.title:SetFontObject("GameFontHighlight", 24)
	RH_HealerManaBar.title:SetPoint("RIGHT", RH_HealerManaBar, "RIGHT", -paddingH, 0)

	RH_HealerManaBar.header = RH_HealerManaBar:CreateFontString(nil, "OVERLAY")
	RH_HealerManaBar.header:SetFontObject("GameFontHighlight", 24)
	RH_HealerManaBar.header:SetPoint("LEFT", RH_HealerManaBar, "LEFT",paddingH, 0)	
	RH_HealerManaBar.header:SetText("Healer Mana");

	RH_ManaBar.title = RH_ManaBar:CreateFontString(nil, "OVERLAY")
	RH_ManaBar.title:SetFontObject("GameFontHighlight", 24)
	RH_ManaBar.title:SetPoint("RIGHT", RH_ManaBar, "RIGHT", -paddingH, 0)

	RH_ManaBar.header = RH_ManaBar:CreateFontString(nil, "OVERLAY")
	RH_ManaBar.header:SetFontObject("GameFontHighlight", 24)
	RH_ManaBar.header:SetPoint("LEFT", RH_ManaBar, "LEFT",paddingH, 0)	
	RH_ManaBar.header:SetText("Overall Mana");

	RH_BuffBar.title = RH_BuffBar:CreateFontString(nil, "OVERLAY")
	RH_BuffBar.title:SetFontObject("GameFontHighlight", 24)
	RH_BuffBar.title:SetPoint("RIGHT", RH_BuffBar, "RIGHT", -paddingH, 0)

	RH_BuffBar.header = RH_BuffBar:CreateFontString(nil, "OVERLAY")
	RH_BuffBar.header:SetFontObject("GameFontHighlight", 24)
	RH_BuffBar.header:SetPoint("LEFT", RH_BuffBar, "LEFT",paddingH, 0)	
	RH_BuffBar.header:SetText("Buffs");

	RH_Popup = CreateFrame("Frame","RH_Popup",RH_MainFrame)
	RH_Popup:SetBackdrop( { 
		bgFile = "Interface\\TOoltips\\ChatBubble-Background", 
		tile = true, tileSize = 16
		});
	RH_Popup:SetBackdropColor(0,0,0,1)
	RH_Popup:SetSize(200,200)
	RH_Popup:SetFrameLevel(99999)
	RH_Popup:Hide()
	RH_Popup.header = RH_Popup:CreateFontString(nil, "OVERLAY")
	RH_Popup.header:SetFontObject("GameFontHighlight", 24)
	RH_Popup.header:SetPoint("TOPLEFT", RH_Popup, "TOPLEFT", paddingH, -paddingH)	
	RH_Popup.header:SetText("Healer List");

	for i = 1,15,1 do
		RH_Popup["textline"..i] = RH_Popup:CreateFontString(nil, "OVERLAY")
		RH_Popup["textline"..i]:SetFontObject("GameFontHighlight", 24)
		RH_Popup["textline"..i]:SetPoint("TOPLEFT", RH_Popup, "TOPLEFT", paddingH, -paddingH - i*20)	
		RH_Popup["textline"..i]:SetText("Healer List");
		RH_Popup["textline"..i]:Hide()
		RH_Popup["textlineP"..i] = RH_Popup:CreateFontString(nil, "OVERLAY")
		RH_Popup["textlineP"..i]:SetFontObject("GameFontHighlight", 24)
		RH_Popup["textlineP"..i]:SetPoint("TOPRIGHT", RH_Popup, "TOPRIGHT", -paddingH, -paddingH - i*20)	
		RH_Popup["textlineP"..i]:SetText("100%");
		RH_Popup["textlineP"..i]:Hide()
	end
end

function RH_MainFrame_OnMouseDown()
	RH_MainFrame:StartMoving()
end

function RH_MainFrame_OnMouseUp()
	RH_MainFrame:StopMovingOrSizing()
end

function RH_mysplit(inputstr, sep)
	if sep == nil then
			sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
			table.insert(t, str)
	end
	return t
end

function RH_contains(table, val)
	for i=1,#table do
	   if table[i] == val then 
		  return true
	   end
	end
	return false
 end