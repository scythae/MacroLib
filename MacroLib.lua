-- MacroLib addon.
-- By Mortarez. 2015.07.18

MacroLib_ver = "v1.10";
MacroLib_title = ("MacroLib " .. MacroLib_ver);
MacroLib_HelpInfo = {
"MacroLib addon for Vanilla-WoW.",
"Gives some additional tools for making macro.",
"`Macro pseudo language is similar to a Blizzard macrolanguage since TBC patch (with some modifications for an addon code simplifying):",
"1.)`",
"/macrolib #showtooltip` - using it in macro will cause updating macro's icon and tooltip on actionbars, to match macro action. Works with 'cast', 'equip' and 'equipslot' commands.",
"2.)`",
"/macrolib cast [conditions1] SpellName1; [conditions2] SpellName2` - for [conditions1] macro will cast 'SpellName1', if conditions from [conditions1] are not satisfied, then macro checks [conditions2], etc.",
"Spellname with omitted rank will be casted using max available rank.",
"Conditions:`",
"combat` - checks whether player in combat (has aggro).",
"mod:alt/shift/ctrl` - checks whether modifier key (alt,shift,ctrl) is pressed. If modifier name is omitted, then options checks any pressed modifier.",
"stance:1/2/3/4/5/6/7, s:1/2/3/4/5/6/7` - checks whether player in stance (druid's shapeshifting forms, rogue's stealth, warrior's stances, priest's shadowform, paladin's auras). Stance index may be omitted.",
"buff:%buffname%, b:%buffname%` - checks for buff on player. Counts only buffs, acquired or lost after entering the world.",
"equipped:%itemname%, e:%itemname%` - checks whether player wears specified item. 'itemname' parameter may be exact name of item, or may be an item subtype. List of supported item subtype will be shown by '/macrolib itemsubtypes' command.",
"target:%unit%, t:%unit%` - changes target for current action. 'unit' parameter may be one of 'target', 'player', 'mouseover', 'targettarget' or 'pet' (also short aliases may be used: 't', 'pl', 'mo', 'tt'). If specified target doesn't exist, then condition will not be satisfied.",
"no` - using 'no' prefix before condition will invert it, so your spell will be casted when, for example, not in combat.",
"3.)`",
"/macrolib equip [conditions1] ItemName1; [conditions2] ItemName2;` - similar to '/macrolib cast'. This command will pick an item from backpack and set that item to worn inventory, in first accessible inventory slot. If item already equipped, nothing will happen.",
"/macrolib equipslot [conditions1] InventorySlot ItemName1; [conditions2] InventorySlot ItemName2;` - an expansion of '/macrolib equip' command. Allows to specify an inventory slot for item, generally need for weapons. 'InventorySlot' parameter must be a number between 1 and 19 inclusive.",
"4.)`",
"/macrolib startattack [conditions]` - toggles off attacking with melee weapon.",
"/macrolib stopattack [conditions]` - toggles off attacking with melee weapon.",
"/macrolib stopcasting [conditions]` - interrupts spell currently being cast.",
"/macrolib cancelform [conditions]` - cancels player's shapeshift, aura, shadowform, etc.",
"5.)`",
"/macrolib seticon [conditions1] RaidIcon1; [conditions2] RaidIcon2;` - command will mark a target with a raid icon. 'RaidIcon' parameter may be one of 'Star', 'Circle', 'Diamond', 'Triangle', 'Moon', 'Square', 'Cross', 'Skull' or 'None' (to unassign an icon).",
"Examples:`",
"/macrolib cast [mod:alt] Healing Touch(Rank 2); [mod:shift] Regrowth(Rank 1); Rejuvenation",
"/macrolib cast [t:mouseover][t:target][t:player] Blind";
"/macrolib cast [t:mo,nomod][t:t,nomod][t:pl,nomod] Gouge; [t:mo][t:t][t:pl] Blind";
"/macrolib cast [nostance:2] Cat Form; [nocombat,nobuff:Prowl] Prowl; Tiger's Fury",
"/macrolib cast [nostance, nocombat] Stealth; [equipped:Daggers] Ambush; Cheap Shot",
"/macrolib cast [e:Shields] Shield Bash; Pummel",
"/macrolib equipslot [mod:alt] 16 Julie's Dagger; 16 Krol Blade",
"/macrolib seticon [t:mo,mod:shift] Skull;[t:mo, nomod] Cross; [t:mo] None"
}

local SlashCmd = "/macrolib";

local IsAttacking = false;

local Color = {
  ["White"] = "|cffFFFFFF",
  ["Red"] = "|cffff0000",
  ["Green"] = "|cff1eff00",
  ["Blue"] = "|cff0070dd",
  ["Yellow"] = "|cffffff00",
  ["Black"] = "|c0000000f"
};

local ModifiersState = {
	["alt"] = false,
	["shift"] = false,
	["ctrl"] = false
};
local MouseoverName;

local ItemSubTypesOneHand = {
	["One-Hand"] = {16, 17},
	["One-Handed Axes"] = {16, 17},
	["One-Handed Maces"] = {16, 17},
	["One-Handed Swords"] = {16, 17},
	["Daggers"] = {16, 17},
	["Fist Weapons"] = {16, 17},	
	["Miscellaneous"] = {16, 17},
};

local ItemSubTypesTwoHand = {
	["Two-Hand"] = {16},	
	["Two-Handed Axes"] = {16},
	["Two-Handed Maces"] = {16},
	["Two-Handed Swords"] = {16},
	["Polearms"] = {16},
	["Staves"] = {16},
	["Fishing Pole"] = {16},		
};

local ItemSubTypesRanged = {
	["Ranged"] = {18},
	["Bows"] = {18},
	["Guns"] = {18},
	["Thrown"] = {18},
	["Wands"] = {18},
	["Crossbows"] = {18},
	["Librams"] = {18},
	["Idols"] = {18},
	["Totems"] = {18}		
};

local ItemSubTypesOther = {
	["Shields"] = {17},		
	["Miscellaneous"] = {16, 17},
};

local GTT = getglobal("GameTooltip");
local GTTOnShowBaseEvent;
local GTTOnHideBaseEvent;

Macrolib_CurrentBuffs = {}; 

local MacroIconsUpdating = false;
local PermittedActionButtons = {
	["MultiBarBottomLeftButton"]=1,
	["MultiBarBottomRightButton"]=1,
	["MultiBarLeftButton"]=1,
	["MultiBarRightButton"]=1,
	["ActionButton"]=1,
	["BonusActionButton"]=1
}; 

local MacroIconUpdatingEvents = {
	["ACTIONBAR_SLOT_CHANGED"]=1,
	["PLAYER_ENTERING_WORLD"]=1,
	["UNIT_MODEL_CHANGED"]=1,
	["PLAYER_REGEN_DISABLED"]=1,
	["PLAYER_REGEN_ENABLED"]=1,
	["ITEM_LOCK_CHANGED"]=1,	
	["PLAYER_AURAS_CHANGED"]=1,
	["SPELL_UPDATE_COOLDOWN"]=1,
	["ACTIONBAR_UPDATE_COOLDOWN"]=1,
	["ACTIONBAR_UPDATE_USABLE"]=1,
	["ACTIONBAR_UPDATE_STATE"]=1,
	["PLAYER_TARGET_CHANGED"]=1,
	["BAG_UPDATE_COOLDOWN"]=1
}; 

local EventsForInspecting = {
	-- ["CHAT_MSG_COMBAT_SELF_MISSES"]=1,
	-- ["CHAT_MSG_COMBAT_SELF_MISSES"]=1
	-- ["UNIT_INVENTORY_CHANGED"]=1,
	-- ["ITEM_LOCK_CHANGED"]=1
	-- ["UNIT_COMBAT"]=1
	-- ["CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"]=1
}; 

local DarkActionButtons = {}; 
local TargetUnit_Default = TargetUnit;
local UnitExists_Default = UnitExists;
local UnitName_Default = UnitName;

function MacroLib_OnEvent()
	if (event == "VARIABLES_LOADED") then 
		MacroLib_OnLoad(); 
	elseif (event == "PLAYER_ENTER_COMBAT") then 
		IsAttacking = true;	
	elseif (event == "PLAYER_LEAVE_COMBAT") then 
		IsAttacking = false;
	elseif (event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS") then 
		MacroLib_AddBuffToList();	
	elseif (event == "CHAT_MSG_SPELL_AURA_GONE_SELF") then 
		MacroLib_RemoveBuffFromList();		
	elseif MacroIconUpdatingEvents[event] then 
		MacroLib_UpdateMacroRepresentation(true, true);	
	elseif EventsForInspecting[event] then
		ml_InspectEvent();	
	else
		ml_InspectEvent();			
	end;
end;

function MacroLib_AddBuffToList()
	if not arg1 then return; end;
	local BuffName = string.gsub(arg1, "^You gain (.+)%.$", "%1");
	Macrolib_CurrentBuffs[BuffName] = true;
end;

function MacroLib_RemoveBuffFromList()
	if not arg1 then return; end;
	local BuffName = string.gsub(arg1, "^(.+) fades from you%.$", "%1");
	Macrolib_CurrentBuffs[BuffName] = false;
end;

function MacroLib_EnumBuffsFromList()
	local BuffName, IsActive;
	for BuffName, IsActive in Macrolib_CurrentBuffs do
		if IsActive then
			ml_Print(BuffName);
		end
	end;
end;
-- chat msg combat self hits
function MacroLib_OnLoad()
	this:RegisterEvent("PLAYER_ENTER_COMBAT");
	this:RegisterEvent("PLAYER_LEAVE_COMBAT");	
	this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");		
	--this:RegisterAllEvents();
	local tmpEvent;	
	for tmpEvent in MacroIconUpdatingEvents do
		this:RegisterEvent(tmpEvent);
	end;	
	for tmpEvent in EventsForInspecting do
		this:RegisterEvent(tmpEvent);
	end;		
	this:SetScript("OnUpdate", MacroLib_OnUpdate);	
	
  	SlashCmdList["MACROLIB"] = MacroLib_ExecCommand;
   	SLASH_MACROLIB1 = SlashCmd; 
	
	ml_GameTooltipEventsModify();	
	
	ml_Print(MacroLib_title .. " loaded. Type '"..SlashCmd.." help' for info.");
	MacroLibParser_OnLoad();		
end;

function MacroLib_OnUpdate()
	if MacroLib_CheckModifiersStateWasChanged() 
	or MacroLib_CheckMouseoverWasChanged() then		
		MacroLib_UpdateMacroRepresentation(true, true);			
	end;
	
	MacroLib_UpdateDarkenedActionButtons();
end; 

function MacroLib_UpdateDarkenedActionButtons()
	local ActionButtonName, ActionButton, ActionType, ActionId;
	
	for ActionButtonName in DarkActionButtons do
		ActionButtonIcon = getglobal(ActionButtonName.."Icon");
		if ActionButtonIcon then			
			ActionButtonIcon:SetVertexColor(0.4, 0.4, 0.4);
		end;		
	end;
end; 

local function UpdateModifierIfChanged(ModKey, ModState)
	if ModifiersState[ModKey] ~= ModState then
		ModifiersState[ModKey] = ModState;
		return true;
	end;
	return false;	
end;

function MacroLib_CheckModifiersStateWasChanged()
	return
		UpdateModifierIfChanged("alt", ml_Alt())
		or UpdateModifierIfChanged("shift", ml_Shift())
		or UpdateModifierIfChanged("ctrl", ml_Ctrl());
end; 

function MacroLib_CheckMouseoverWasChanged()
	local NewMouseoverName = UnitName('mouseover');
	if NewMouseoverName ~= MouseoverName then
		MouseoverName = NewMouseoverName;
		return true;
	end;
	
	return false;	
end; 

function MacroLib_ExecCommand(Command)
	if (Command == "help") or (Command == "") then
		MacroLib_ShowHelpFile();		
		return;
	elseif (Command == "itemsubtypes") then
		ml_PrintItemSubtypes();		
		return;
	end;	
		
	local CommandType, CommandVal = MacroLibParser_GetCommand(Command);
	if not CommandType or not CommandVal then return; end;
			
	if CommandType == "cast" then
		MacroLib_TargetedCommandExecution(CastSpell, {CommandVal, BOOKTYPE_SPELL})
	elseif (CommandType == "seticon") then 
		MacroLib_TargetedCommandExecution(SetRaidTarget, {'target', CommandVal});
	elseif CommandType == "equip" then
		ml_EquipItem(CommandVal);
	elseif CommandType == "equipslot" then
		ml_EquipItem(CommandVal, MacroLibParser_LastWantedInventorySlot);		
	elseif CommandType == "startattack" then
		ml_StartAttack();
	elseif CommandType == "stopattack" then
		ml_StopAttack();	
	elseif CommandType == "stopcasting" then
		SpellStopCasting();
	elseif CommandType == "cancelform" then
		ml_CancelShapeshift();				
	end;		
end;

function MacroLib_TargetedCommandExecution(CommandExecution, args)
	local Target = MacroLibParser_LastWantedTarget;
	local NeedChangeTarget = (Target ~= nil) and not UnitIsUnit(ml_RefineUnitNameIfMouseover(Target), 'target');
	
	if NeedChangeTarget then
		TargetUnit(Target);
	end;
	CommandExecution(unpack(args));
	
	if NeedChangeTarget then
		TargetLastTarget();
	end;	
end;

function MacroLib_ShowHelpFile()
	local LineNum, Line;
	for LineNum, Line in MacroLib_HelpInfo do
		ml_PrintHelp(Line);
	end	
end;

function MacroLib_SlashCmd()
	return SlashCmd;
end;

function ml_Alt()
	if IsAltKeyDown() then
		return true;	
	else
		return false;
	end;
end

function ml_Shift()
	if IsShiftKeyDown() then
		return true;	
	else
		return false;
	end;
end

function ml_Ctrl()
	if IsControlKeyDown() then
		return true;	
	else
		return false;
	end;	
end

function ml_Mod()
	return ml_Alt() or ml_Shift() or ml_Ctrl();	
end

function ml_Print(Text)
	DEFAULT_CHAT_FRAME:AddMessage(Text);
end

function ml_Debug(Text)
	ml_Print("MLDebug. "..(Text or ""));
end;

function ml_Error(Text, ShowLastMacro)
	local MacroName = "";
	if ShowLastMacro then
		 MacroName = "Macro '"..(MacroLibParser_LastParsedMacro or "<emptyname>").."'. ";
	end;
	
	ml_Print("MacroLib. "..MacroName..(Text or ""));
end;

function ml_CancelShapeshift()
	local Shapeshifted, FormIndex = ml_Shapeshifted();
	if Shapeshifted then
		CastShapeshiftForm(FormIndex);
	end;	
end;

function ml_Shapeshifted(FormIndex)
	if FormIndex then
		local _, _, ShapeshiftIsActive = GetShapeshiftFormInfo(FormIndex); 
		return (ShapeshiftIsActive == 1), FormIndex;
	end;
	
	local i;
	for i = 1, GetNumShapeshiftForms() do
		if ml_Shapeshifted(i) then
			return true, i;
		end;
	end;
	return false, nil;
end;

function ml_IsAttack()
	if not PlayerFrame then
		return IsAttacking;
	end;
	
	if PlayerFrame.inCombat then
		return true;
	else
		return false;
	end;	
end;

function ml_InCombat()
	if UnitAffectingCombat("player") then
		return true;
	else
		return false;
	end;
end;

function ml_StartAttack()
	if not ml_IsAttack() then
		AttackTarget();
	end;
end;

function ml_StopAttack()
	if ml_IsAttack() then
		AttackTarget();
	end;
end;


function ml_Sleep(ms)
	ms = ms / 1000.0;
	local ExitTime = GetTime() + ms;
	repeat
	until GetTime() >= ExitTime;
end;

function ml_BoolToStr(Val)
	if Val then
		return "True";
	else
		return "False";
	end;
end;

function ml_AnyToBool(Val)
	if Val then
		return true;
	else
		return false;
	end;
end;

function ml_PrintHelp(Text)
	local Lexem, RestText = MacroLib_CutLexem(Text, "`"); 
	DEFAULT_CHAT_FRAME:AddMessage(Color["Yellow"]..Lexem..Color["White"]..RestText);
end

function MacroLib_CutLexem(Text, Delimiter)
	local Lexem = "";
	local RestText = Text;
	local DelimPos = strfind(Text, Delimiter, 1, true);
	
	if (DelimPos ~= nil) then
		Lexem = strsub(Text, 1, DelimPos - 1);	
		RestText = strsub(Text, DelimPos + 1);
	end;

	return Lexem, RestText; 
end;

function ml_PrintTable(Table, Term)
	if not Table then
		ml_Print("<nilTable>");
		return;
	end
	local val;
	for _, val in Table do
		if val == nil then
			ml_Print("<nil> value in a table, loop broken");
			break;
		else
			ml_Print((val or "<nil>")..(Term or ""));
		end
	end;
end

function ml_InspectEvent()
	local _, str;
	for _, str in pairs({event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9}) do
		ml_Print(str);
	end;
end;

function MacroLib_GetMacroAction(Button)
	if not MacroLib_ButtonIsAnActionButton(Button) then return; end;
	
	local IsMacro, MacroName, MacroIcon, MacroBody = MacroLib_ActionButtonIsMacro(Button);
	if not IsMacro then return; end;
	
	local ActionType, ActionId;
	local CommandType, CommandVal = MacroLibParser_GetActiveCommandFromMacro(MacroBody, MacroName);
	if not CommandType then 
		ActionType = "macro";
		ActionId = GetMacroIndexByName(MacroName); 
	elseif CommandType == "cast" then 
		ActionType = "spell";
		ActionId = CommandVal; 	
	elseif (CommandType == "equip") or (CommandType == "equipslot") then 
		ActionType = "item";
		ActionId = CommandVal; 			
	end;
	 	 
	return ActionType, ActionId;
end;

function MacroLib_ButtonIsAnActionButton(Button)
	if not Button then return false; end;
	
	local Name = Button:GetName();
	if not Name then return false; end;
	local NamePattern = string.gsub(Name, "^(%a+)%d+$", "%1");
	
	return PermittedActionButtons[NamePattern];
end;

function MacroLib_ActionButtonIsMacro(ActionButton)	
	local ActionSlot = ActionButton_GetPagedID(ActionButton);
	if not ActionSlot then return false; end;

	local ActionText = GetActionText(ActionSlot);	
	if not ActionText then return false; end;
		
	local MacroId = GetMacroIndexByName(ActionText);
	if not MacroId then return false; end;

	local MacroName, MacroIcon, MacroBody = GetMacroInfo(MacroId);	
	if not MacroBody then return false; end;
	
	return true, MacroName, MacroIcon, MacroBody;	
end;

function MacroLib_UpdateMacroRepresentation(WantUpdateIcon, WantUpdateTooltip)
	if MacroIconsUpdating then return; end;	
	MacroIconsUpdating = true;

	local ActionButton;
	local ActionType, ActionId;
	GetNumMacroIcons();	
	
	if WantUpdateIcon then
		for _, ActionButton in MacroLib_GetActionButtons() do
			ActionType, ActionId = MacroLib_GetMacroAction(ActionButton);
			if ActionId then
				MacroLib_UpdateSingleMacroIcon(ActionButton, ActionType, ActionId);
				MacroLib_UpdateSingleMacroCooldown(ActionButton, ActionType, ActionId);
			end;
		end;
	end

	if WantUpdateTooltip then
		if GTT:IsVisible() then
			ActionButton = GetMouseFocus();	
			ActionType, ActionId = MacroLib_GetMacroAction(ActionButton);
			if ActionId then
				MacroLib_UpdateMacroTooltip(Button, ActionType, ActionId);
			end;
		end;			
	end;
	
	MacroIconsUpdating = false;
end;

function MacroLib_GetActionButtons()	
	local ActionButtons = {};
	local ActionButton;
	local ActionButtonNamePattern;	
	local ActionButtonId;	
	
	for ActionButtonNamePattern in PermittedActionButtons do
		for ActionButtonId = 1, 12 do
			ActionButton = getglobal(ActionButtonNamePattern..ActionButtonId)
			if ActionButton then
				table.insert (ActionButtons, ActionButton)
			end;
		end;
	end;
	return ActionButtons;
end; 

function MacroLib_UpdateSingleMacroIcon(ActionButton, ActionType, ActionId)
	local Icon, Texture, Usable, _;
	local cdStart, cdDuration, cdEnable;
	
	Icon = getglobal(ActionButton:GetName().."Icon");
	if not Icon then		
		ml_Error("Nil icon."..ActionType, 1);
		return;
	end;
	
	if ActionType == "spell" then					
		Texture = GetSpellTexture(ActionId, BOOKTYPE_SPELL);
		cdStart, cdDuration, cdEnable = GetSpellCooldown(ActionId, BOOKTYPE_SPELL);
	elseif ActionType == "item" then
		_, _, _, _, _, _, _, _, Texture = ml_GetItemInfoByName(ActionId);	
	elseif ActionType == "macro" then
		_, Texture = GetMacroInfo(ActionId);
	end;	
	if not Texture then return; end;	
	Icon:SetTexture(Texture);	

	if cdEnable == 0 then			
		DarkActionButtons[ActionButton:GetName()] = 1;
	else
		Icon:SetVertexColor(1, 1, 1);	
		DarkActionButtons[ActionButton:GetName()] = nil;				
	end;	
end;

function MacroLib_UpdateSingleMacroCooldown(ActionButton, ActionType, ActionId)
	local Cooldown, cdStart, cdDuration, cdEnable;
	
	Cooldown = getglobal(ActionButton:GetName().."Cooldown");
	if ActionType == "spell" then					
		cdStart, cdDuration, cdEnable = GetSpellCooldown(ActionId, BOOKTYPE_SPELL);
	end;

	if Cooldown then
		if cdStart and cdDuration and cdEnable then
			CooldownFrame_SetTimer(Cooldown, cdStart, cdDuration, cdEnable);							
		end;
	else
		ml_Error("Nil cooldown."..ActionType, 1);		
	end;			
end;

function MacroLib_UpdateMacroTooltip(ActionButton, ActionType, ActionId)	
	if ActionType == "spell" then
		GTT:SetSpell(ActionId, BOOKTYPE_SPELL);
	elseif ActionType == "item" then
		local _, ItemLink = ml_GetItemInfoByName(ActionId);
		if ItemLink then
			GTT:SetHyperlink(ItemLink);
		end;
	elseif ActionType == "macro" then
		local ActionName = GetMacroInfo(ActionId);	
		GTT:SetText(ActionName);		
	end;
	
	if TheoryCraft_AddTooltipInfo then
		TheoryCraft_AddTooltipInfo(GTT);
	end;
end;

function ml_GTTOnShow()	
	if GTTOnShowBaseEvent then
		GTTOnShowBaseEvent();
	end;
	
	MacroLib_UpdateMacroRepresentation(false, true);
end;

function ml_GTTOnHide()
	if GTTOnHideBaseEvent then
		GTTOnHideBaseEvent();
	end;
end;

function ml_GameTooltipEventsModify()	
	GTTOnShowBaseEvent = GTT:GetScript("OnShow");
	GTT:SetScript( "OnShow", ml_GTTOnShow);
	GTTOnHideBaseEvent =  GTT:GetScript("OnHide");
	GTT:SetScript( "OnHide", ml_GTTOnHide);
end;

function ml_GetSpellIdByName(SpellName)	
	if not SpellName then return; end;	
	local SpellId;
	local tmpSpellName, tmpSpellRank;	
	local BookType = BOOKTYPE_SPELL;
	local NeedRank = strfind(SpellName, "^.+%b()$");	

	for SpellId = ml_GetNumSpells(), 1, -1 do
		tmpSpellName, tmpSpellRank = GetSpellName(SpellId, BookType); 		
		if not tmpSpellName then break; end;
		if NeedRank then
			tmpSpellName = tmpSpellName..gsub(tmpSpellRank, "(.+)", "(%1)");
		end;
		if (SpellName == tmpSpellName) then	
			return SpellId, BookType;
		end;
	end;
end;

function ml_GetNumSpells()	
	local name, texture, offset, numSpells = GetSpellTabInfo(GetNumSpellTabs());
	return offset + numSpells;
end;

function ml_GetItemBagSlotByName(ItemName)	
	if not ItemName then return; end;	
	local BagId, Slot, ItemLink;
		
	for BagId = 0,4 do
		for Slot = 1, GetContainerNumSlots(BagId) do
			ItemLink = GetContainerItemLink(BagId, Slot);
			if ItemLink and strfind(ItemLink, ItemName) then
				return BagId, Slot;
			end;	
		end	
	end	
end;

function ml_GetItemInventorySlotByName(ItemName)	
	if not ItemName then return; end;	
	local InventorySlot, ItemLink;
		
	for InventorySlot = 1,19 do
		ItemLink = GetInventoryItemLink("player", InventorySlot) ;
		if ItemLink and strfind(ItemLink, ItemName) then
			return InventorySlot;
		end;		
	end	
end;

function ml_GetItemLocation(ItemName)	
	if not ItemName then return; end;
	local BagId, Slot = ml_GetItemBagSlotByName(ItemName); 
	local InventorySlot = ml_GetItemInventorySlotByName(ItemName);
	return BagId, Slot, InventorySlot
end;

function ml_EquipCursorItem(ToInventorySlot)
	if ToInventorySlot then
		EquipCursorItem(ToInventorySlot);
	else
		AutoEquipCursorItem();
	end;
end;

function ml_EquipItem(ItemName, ToInventorySlot)
	local BagId, BagSlot = ml_GetItemBagSlotByName(ItemName);
	if BagId and BagSlot then
		PickupContainerItem(BagId, BagSlot);
		ml_EquipCursorItem(ToInventorySlot);		
		return;
	end;	
	
	local FromInventorySlot = ml_GetItemInventorySlotByName(ItemName);
	if FromInventorySlot and (FromInventorySlot ~= ToInventorySlot) then
		PickupInventoryItem(FromInventorySlot);
		ml_EquipCursorItem(ToInventorySlot);
		return;
	end;
end;

function ml_GetItemInfoByName(ItemName)
	local ItemId = ml_GetItemIdByName(ItemName);	
	if not ItemId then return; end;

	local Name, Link, Rarity, LvlRequired, Type, SubType, StackCount, EquipLoc, ItemTexture = GetItemInfo(ItemId);
	return Name, Link, Rarity, LvlRequired, Type, SubType, StackCount, EquipLoc, ItemTexture;
end;

function ml_GetItemIdByName(ItemName)
	local ItemLink = ml_GetItemLinkByName(ItemName);
	local ItemId = ml_GetItemIdByLink(ItemLink);	
	return ItemId;
end;

function ml_GetItemLinkByName(ItemName)
	local BagId, Slot, InventorySlot = ml_GetItemLocation(ItemName);
	local ItemLink;
	if BagId and Slot then
		ItemLink = GetContainerItemLink(BagId, Slot);
	elseif InventorySlot then
		ItemLink = GetInventoryItemLink("player", InventorySlot);
	end;
	return ItemLink;
end;

function ml_GetItemIdByLink(ItemLink)
	if not ItemLink then return; end;
	local ItemId = string.gsub(ItemLink, "^.*|Hitem:(%d+):.*$", "%1");	
	return tonumber(ItemId);
end;

function ml_GetItemInfoByLink(ItemLink)
	local ItemId = ml_GetItemIdByLink(ItemLink);	
	if not ItemId then return; end;
	
	local Name, Link, Rarity, LvlRequired, Type, SubType, StackCount, EquipLoc, ItemTexture = GetItemInfo(ItemId);
	return Name, Link, Rarity, LvlRequired, Type, SubType, StackCount, EquipLoc, ItemTexture;
end;

function ml_PrintItemInfo(ItemName)
	local ItemId = ml_GetItemIdByName(ItemName);	
	if not ItemId then return; end;
	
	ml_Print("------");		
	local _, str;
	for _, str in pairs({GetItemInfo(ItemId)}) do
		ml_Print(str);
	end;
end;

function ml_PrintItemSubtypes()
	local f = function(SubtypeTable) 
		local Subtype;
		for Subtype in SubtypeTable do
			ml_PrintHelp(Subtype);
		end	
	end;
	ml_PrintHelp("List of item subtypes for MacroLib addon:`");
	f(ItemSubTypesOneHand);
	f(ItemSubTypesTwoHand);
	f(ItemSubTypesRanged);
	f(ItemSubTypesOther);
	ml_PrintHelp("End of list.`");	
end

function ml_IsItemSubtypeInInventorySlot(WantedSubtype, InventorySlot)
	if not InventorySlot then return false; end;
	
	local ItemLink = GetInventoryItemLink("player", InventorySlot);
	local _, _, _, _, _, RealSubtype = ml_GetItemInfoByLink(ItemLink);
	
	local Result;
	if (WantedSubtype == "One-Hand") then
		Result = ItemSubTypesOneHand[RealSubtype];
	elseif (WantedSubtype == "Two-Hand") then
		Result = ItemSubTypesTwoHand[RealSubtype];
	elseif (WantedSubtype == "Ranged") then
		Result = ItemSubTypesRanged[RealSubtype];
	else
		Result = (RealSubtype == WantedSubtype);
	end;
	
	return ml_AnyToBool(Result);
end;

function ml_IsItemEquipped(ItemName, WantedInventorySlot)
	local DefaultInventorySlot, ItemId, ItemLink, _;
	
	local DefaultInventorySlots = ItemSubTypesOneHand[ItemName]
		or ItemSubTypesTwoHand[ItemName]
		or ItemSubTypesRanged[ItemName]
		or ItemSubTypesOther[ItemName];
		
	if DefaultInventorySlots then	
		if WantedInventorySlot then
			return ml_IsItemSubtypeInInventorySlot(ItemName, WantedInventorySlot);
		end;
		
		for _, DefaultInventorySlot in DefaultInventorySlots do
			if ml_IsItemSubtypeInInventorySlot(ItemName, DefaultInventorySlot) then
				return true;
			end;
		end;
		
		return false;
	end;
	
	local RealInventorySlot = ml_GetItemInventorySlotByName(ItemName);
	if not RealInventorySlot then return false; end;	
	if not WantedInventorySlot then return true; end;	
	return (WantedInventorySlot == RealInventorySlot);	
end;

function TargetUnit(UnitName)
	UnitName = ml_RefineUnitNameIfMouseover(UnitName);
	TargetUnit_Default(UnitName);
end;

function UnitExists(UnitName)
	UnitName = ml_RefineUnitNameIfMouseover(UnitName);	
	return UnitExists_Default(UnitName);
end;

function UnitName(UnitName)
	UnitName = ml_RefineUnitNameIfMouseover(UnitName);	
	return UnitName_Default(UnitName);
end;

function ml_RefineUnitNameIfMouseover(UnitName)
	if UnitName and string.lower(UnitName) == 'mouseover' then
		UnitName = ml_MouseoverFromFrame();
	end;	
	
	return UnitName;
end;

function ml_MouseoverFromFrame()
	local UnitName = 'mouseover';
	
	local frametype, framename, frame = ml_FrameFromMouse();
	if not frametype 
	or not framename 
	or not frame then
		return UnitName;
	end;
		
	if strfind(frametype, 'PartyMemberFrame') then
		UnitName = 'party'..frame:GetID();
	elseif strfind(frametype, 'PlayerFrame') then		
		UnitName = 'player';	
	elseif strfind(frametype, 'TargetFrame') then		
		UnitName = 'target';
	elseif strfind(frametype, 'RaidPullout%d+Button%d+ClearButton') then	
		UnitName = frame.unit;			
	end			
	
	return UnitName;
end;

function ml_FrameFromMouse()
	local Frame = GetMouseFocus(); 
	if not Frame then return; end;
	
	local FrameName, FrameType, FrameID = Frame:GetName(), Frame:GetObjectType(), Frame:GetID();
	return FrameName, FrameType, Frame;
end;

function ml_MouseoverInfo()
	local frametype, framename, frame = ml_FrameFromMouse();
	ml_Print(frametype..' '..framename);
	ml_Print(frame.unit);
end;















