-- MacroLibParser unit for MacroLib addon.
-- By Mortarez. Actual date on MacroLib.lua unit.

local SlashCmd = MacroLib_SlashCmd();
MacroLibParser_LastParsedMacro = "";
MacroLibParser_LastWantedInventorySlot = 0;
MacroLibParser_LastWantedTarget = nil;
local WantInventorySlot = false;
local mlp_DebugMode = false;

local CommandsChangingMacroRepresentation = {
	["cast"]=1,
	["equip"]=1,
	["equipslot"]=1
};

local RegularCommands = {
	["startattack"]=1,
	["stopattack"]=1,
	["stopcasting"]=1,
	["cancelform"]=1	
};

local AvailableTargets = {
	["target"]="target",
	["t"]="target",
	["mouseover"]="mouseover",
	["mo"]="mouseover",
	["player"]="player",	
	["pl"]="player",
	["targettarget"]="targettarget",
	["tt"]="targettarget",
	["mot"]="mouseovertarget",	
	["mouseovertarget"]="mouseovertarget"	
};

local TargetIconIndexes = {
    ["None"] = 0,
    ["Star"] = 1,
    ["Circle"] = 2,
    ["Diamond"] = 3,
    ["Triangle"] = 4,
    ["Moon"] = 5,
    ["Square"] = 6,
    ["Cross"] = 7,
    ["Skull"] = 8
}

local function PrintTable(Table, Term)
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

local function Trim(Text, TrimChar)
	if not Text then return; end;
	TrimChar = TrimChar or " ";
	return string.gsub(Text, "^["..TrimChar.."]*(.-)["..TrimChar.."]*$", "%1", 1);
end;

local function DeleteBrackets(Text)
	return strsub(Text, 2, -2);
end;

local function CutLexem(Text, Delimiter)
	if not strfind(Text, Delimiter) then
		return Text, nil;
	end;
	
	Text = Trim(Text, Delimiter);	
	local Lexem = string.gsub(Text, "^(.-)["..Delimiter.."]+.*$", "%1");
	local RestText = string.gsub(Text, "^.-["..Delimiter.."]+(.*)$", "%1");
	
	return Lexem, RestText; 
end;

local function StrSplit(Text, Delimiter)
	if not Text 
		or Text == ""
		or not Delimiter
		or Delimiter == ""
	then
		return nil;
	end;
		
	local t = {};
	if not strfind(Text, Delimiter) then
		table.insert (t, Text);
		return t;
	end;
	
	local str;
	for str in string.gfind(Text, "[^"..Delimiter.."]+") do
		table.insert (t, str);
	end;

	return t;
end;

local function Condition_Target(Params)
	return UnitExists(MacroLibParser_LastWantedTarget);
end;

local function Condition_Buff(Params)
	if not Params then return false; end;
	
	local BuffName = string.gsub(Params[1], "^%s*(.+)%s*$", '%1');
	if Macrolib_CurrentBuffs[BuffName] then
		return true;		
	else
		return false;
	end;		
end;

local function Condition_ExtractItemEquipInfo(ItemEquipInfo)
	local ItemName, InventorySlot;
	if strfind(ItemEquipInfo, "^%s*(%d+)%s.*$") then
		InventorySlot, ItemName = CutLexem(ItemEquipInfo, " ");
		InventorySlot = tonumber(InventorySlot);
	else
		ItemName = ItemEquipInfo;
	end;
		
	return Trim(ItemName), InventorySlot;
end;

local function Condition_Equipped(Params)
	if not Params then return false; end;	

	local ItemEquipInfo, ItemName, InventorySlot;
	for _, ItemEquipInfo in Params do
		ItemName, InventorySlot = Condition_ExtractItemEquipInfo(ItemEquipInfo)
		if ml_IsItemEquipped(ItemName, InventorySlot) then
			return true;
		end;
	end;		
end;

local function Condition_Combat(Params)
	return ml_InCombat();		
end;

local function Condition_Stance(Params)
	if not Params then return ml_Shapeshifted(); end;
	
	local CertainStance;
	for _, CertainStance in Params do
		if ml_Shapeshifted(CertainStance) then
			return true;
		end;
	end;	
	return false;	
end;

local function CertainModifierSatisfied(CertainModifier)
	return 
		((CertainModifier == "alt") and ml_Alt())
		or ((CertainModifier == "ctrl") and ml_Ctrl())
		or ((CertainModifier == "shift") and ml_Shift());
end;

local function Condition_Mod(Params)
	if not Params then return ml_Mod(); end;
	
	local CertainModifier;
	for _, CertainModifier in Params do
		if CertainModifierSatisfied(CertainModifier) then
			return true;
		end;
	end;	
	return false;	
end;

local function IsConditionNegated(Condition)
	if not Condition then return false, nil; end;
	local NegatedCondition = string.gsub(Condition, "^no(.-)$", "%1", 1);
	
	return (NegatedCondition ~= Condition), NegatedCondition;
end;

local function ParseCondition(Condition)
	local ConditionType, RestText = CutLexem(Condition, ":");
	local ConditionParams = StrSplit(RestText, "/");
	return ConditionType, ConditionParams;
end;

local Condition_Functions = {
	["mod"] = Condition_Mod,
	["combat"] = Condition_Combat,
	["b"] = Condition_Buff,
	["buff"] = Condition_Buff,
	["e"] = Condition_Equipped,
	["equipped"] = Condition_Equipped,
	["stance"] = Condition_Stance,
	["s"] = Condition_Stance
};

local Condition_Functions_Targeting = {
	["t"] = Condition_Target,
	["target"] = Condition_Target
};

local function SingleConditionSatisfied(Condition)
	local Type, Params = ParseCondition(Condition);
	local Negated, Type = IsConditionNegated(Type);
	
	if Condition_Functions[Type] then 
		ConditionSatisfied = Condition_Functions[Type](Params);
	elseif Condition_Functions_Targeting[Type] then 
		ConditionSatisfied = Condition_Functions_Targeting[Type](Params);
	else
		ml_Error("Unknown condition: "..Type, 1);
	end;

	
	if Negated then
		return not ConditionSatisfied;
	else
		return ConditionSatisfied;
	end;
end;

local function ExtractConditionBlocks(ConditionalAction)
	local ConditionBlocks = {};
	local ConditionBlock;
	
	local ConditionsList;
	for ConditionsList in string.gfind(ConditionalAction or "", "%[(.-)%]") do
		ConditionBlock = StrSplit(ConditionsList, ",");
		if ConditionBlock then			
			table.insert (ConditionBlocks, ConditionBlock);
		end;
	end;
	
	return ConditionBlocks;
end;

local function ScanConditionBlockForTarget(ConditionBlock)
	local _, Condition;
	local Type, Params;
	local Target;
	
	for _, Condition in ConditionBlock do
		Type, Params = ParseCondition(Condition);
		if Condition_Functions_Targeting[Type] then
			Target = Params[1];
		end;
	end;	
	
	if AvailableTargets[Target] then
		Target = AvailableTargets[Target];
	elseif Target then
		ml_Error("Unknown target: "..Target, 1);
		Target = nil;
	end;

	return Target;
end;

local function AllConditionsSatisfied(ConditionalAction)
	local Satisfied = true;
	local ConditionBlock;
	local Condition, Cnum, CBnum;
	MacroLibParser_LastWantedTarget = 'target';
	
	for CBnum, ConditionBlock in ExtractConditionBlocks(ConditionalAction) do		
		MacroLibParser_LastWantedTarget = ScanConditionBlockForTarget(ConditionBlock);		
		for Cnum, Condition in ConditionBlock do
			Condition = Trim(Condition);	
			Satisfied = SingleConditionSatisfied(Condition);
			if not Satisfied then break; end;
		end;		
		if Satisfied then break; end;
	end;
	return Satisfied;
end;

local function ExtractUnconditionedVal(ConditionedVal)
	local UnconditionedVal = string.gsub(ConditionedVal, "^.-%[.*%]%s*(.-)%s*$", "%1");
	return Trim(UnconditionedVal);				
end;

local function ExtractSpellId(SpellWithOptions)
	local SpellName = ExtractUnconditionedVal(SpellWithOptions);
	local SpellId = ml_GetSpellIdByName(SpellName);
	return SpellId;
end;

local function ParseCastSpell(SpellList)
	local _, ConditionalSpell;
	local SpellId;
	for _, ConditionalSpell in StrSplit(SpellList, ";") do
		SpellId = ExtractSpellId(ConditionalSpell);
		if AllConditionsSatisfied(ConditionalSpell) then		
			return SpellId;		
		end;
	end;	
end;

local function ParseSetIcon(IconList)
	local _, ConditionalIcon;
	local IconIndex;
	for _, ConditionalIcon in StrSplit(IconList, ";") do
		IconIndex = TargetIconIndexes[ExtractUnconditionedVal(ConditionalIcon)];		
		if AllConditionsSatisfied(ConditionalIcon) then
			return IconIndex;		
		end;
	end;	
end;

local function ExtractItemEquipInfo(ItemWithOptions)
	local ItemEquipInfo = ExtractUnconditionedVal(ItemWithOptions);
	local InventorySlot, ItemName;
	if WantInventorySlot then
		InventorySlot, ItemName = CutLexem(ItemEquipInfo, ' ');
		if strfind(InventorySlot, '%D') then
			ml_Error("Incorrect slot for 'equipslot' command.");
			InventorySlot = nil;
		end;		
	else
		ItemName = ItemEquipInfo;
	end;

	return Trim(ItemName), tonumber(InventorySlot);
end;

local function ParseEquipItem(ItemList)
	local ConditionalItem;
	local ItemName, InventorySlot;
	for _, ConditionalItem in StrSplit(ItemList, ";") do
		ItemName, InventorySlot = ExtractItemEquipInfo(ConditionalItem);
		if InventorySlot then 			
			MacroLibParser_LastWantedInventorySlot = InventorySlot;
		end;
		if AllConditionsSatisfied(ConditionalItem) then
			return ItemName;		
		end;
	end;	
end;

local function FakeTable()
	local t = {};
	local i;
	for i =1,10 do
		table.insert (t, nil);
	end;

	return t;
end

local function TestFuncs()
	-- ml_Print(Trim("       cast long sword    ", " ")..".");
	-- PrintTable({CutLexem("   cast long sword  ", " ")}, '.');
    -- PrintTable(StrSplit("a;b][c","][; "));
	-- PrintTable(StrSplit("a,b",","), ".");
	-- PrintTable(FakeTable, ".");
	-- PrintTable(StrSplit("/macrolib startattack\n/run ml_Print(\"Hi\")\n/macrolib stopattack","\n"), ".");	
	-- ml_Print(DeleteBrackets("(awdawd)"));
    -- PrintTable(ExtractCommandsFromMacro(SlashCmd.." 1Command"..SlashCmd.." 2Command"..SlashCmd.." 3Command"));
end;

function MacroLibParser_OnLoad()
	TestFuncs();	
end

local function IsSlashCommandAdressedToMacrolib(SlashCommand)
	if not SlashCommand then return false, nil; end;
	local RecognizedCommand = string.gsub(SlashCommand, "^"..SlashCmd.."%s+(.-)$", "%1", 1);
	return (RecognizedCommand ~= SlashCommand), RecognizedCommand;
end	

local function ExtractCommandsFromMacro(MacroBody)
	local Commands = {};
	
	for _, Command in StrSplit(MacroBody, "\n") do
		CommandAdressedToMacrolib, Command = IsSlashCommandAdressedToMacrolib(Command);
		if CommandAdressedToMacrolib then
			table.insert (Commands, Command)
		end;
	end			

	return Commands;
end; 

function MacroLibParser_GetActiveCommandFromMacro(MacroBody, MacroName)
	MacroLibParser_LastParsedMacro = MacroName;
	if not strfind(MacroBody, SlashCmd.." #showtooltip") then return; end;
	
	local Commands = ExtractCommandsFromMacro(MacroBody);
	local Command;
	local CommandType, CommandVal;	
	
	for _, Command in Commands do
		CommandType, CommandVal = MacroLibParser_GetCommand(Command);
		if CommandType 
			and CommandVal 
			and CommandsChangingMacroRepresentation[CommandType]
		then 
			return CommandType, CommandVal;
		end;		
	end;	
end;

local function ParseRegularCommand(CommandType, CommandText)
	if AllConditionsSatisfied(CommandText) then
		return CommandType;
	end;	
end;

function MacroLibParser_GetCommand(Command)
	local CommandType, RestText = CutLexem(Command, " ");
	if not CommandType then return nil, nil; end;

	local CommandVal;
	if RegularCommands[CommandType] then
		CommandVal = ParseRegularCommand(CommandType, RestText)
	elseif CommandType == "cast" then
		CommandVal = ParseCastSpell(RestText);	
	elseif CommandType == "equip" then
		WantInventorySlot = false;
		CommandVal = ParseEquipItem(RestText);	
	elseif CommandType == "equipslot" then
		WantInventorySlot = true;	
		CommandVal = ParseEquipItem(RestText);	
	elseif CommandType == "seticon" then
		CommandVal = ParseSetIcon(RestText);			
	else
		CommandType = nil;
	end;	
	
	return CommandType, CommandVal;
end;














