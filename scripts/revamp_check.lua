--[[
Copyright (C) braeven, 2022

Author: braeven
Date: 16.04.2022
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.1.0.0 @ 14.05.2022 - Added Option to add own FillTypes to Sellingstation
1.0.0.0 @ 16.04.2022 - Release Initial Version

Important:
Kopiere diese Datei in deine Produktionen um einen Revamp-Versionscheck ausführen zu können.

Copy this File into your Productions to add a Revamp-Versionscheck.
]]

RevampChecker = {}


--Production Revamp: Function to compare the needed with the avaible version of Revamp
function RevampChecker.check(revampVersion, neededVersion)
  local base, major, minor, patch = string.match(revampVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
  RevampChecker.base = math.floor(base)
  RevampChecker.major = math.floor(major)
  RevampChecker.minor = math.floor(minor)
  RevampChecker.patch = math.floor(patch)
  
  local base, major, minor, patch = string.match(neededVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
  base = math.floor(base)
  major = math.floor(major)
  minor = math.floor(minor)
  patch = math.floor(patch)
  if RevampChecker.base > base then
    return true
  elseif RevampChecker.base == base then
    if RevampChecker.major > major then
      return true
    elseif RevampChecker.major == major then
      if RevampChecker.minor > minor then
        return true
      elseif RevampChecker.minor == minor then
        if RevampChecker.patch > patch then
          return true
        elseif RevampChecker.patch == patch then
          return true
        end
      end
    end
  end
  return false
end


--Production Revamp: Callback function for the warning message. Opens the modhub page if needed.
function RevampChecker.done(isYes)
  if isYes == true then
    local link = "mods.php?title=fs2022&searchMod=revamp"
    openWebFile(link, "")
  end
end


--Production Revamp: Warning function - Will generate the warning message for 2 languages
function RevampChecker.warning(revampVersion, neededVersion, modName)
  local title = "Wrong Version of Production Revamp"
  local text = "At least one mod needs a newer version.\n Mod " ..modName.. " needs at least version " ..neededVersion.. " of Production Revamp.\n The installed version is " ..revampVersion.. ", please update to the latest one.\n Support-Discord: discord.gg/gHmnFZAypk"
  local textyes = "Open Modhub"
  local textno = "Ignore"
  local language = g_languageShort
  if language == "de" then
    title = "Veraltete Version von Production Revamp"
    text = "Mindestens ein Mod benötigt eine neuere Version.\n Der Mod " ..modName.. " benötigt Version " ..neededVersion.. " von Production Revamp.\n Die vorhandene Version ist " ..revampVersion.. ", bitte updaten.\n Support-Discord: discord.gg/gHmnFZAypk"
    textyes = "Modhub öffnen"
    textno = "Ignorieren"
  end

  g_gui:showYesNoDialog({
    title = title,
    text = text,
    dialogType = DialogElement.TYPE_WARNING,
    callback = RevampChecker.done,
    target = self,
    yesText = textyes,
    noText = textno
  })
end


--Production Revamp: Checking the Version of Revamp, If the test succeeds, run the SellingStation Script.
function RevampChecker.test ()
  local mods = g_modManager:getActiveMods(FS22_A_ProductionRevamp)
  local revampversion = ""
  
  for index, activemod in pairs(mods) do
    if activemod.title == "Production Revamp" then
      revampversion = activemod.version
    end
  end
  
  local modName = g_currentModName
  local mod = g_modManager:getModByName(modName)
  local xmlFile = XMLFile.load("TempDesc", mod.modFile)
  
  if xmlFile ~= nil and xmlFile ~= 0 then
	local version = xmlFile:getString("modDesc.revamp#minVersion")	
    if version~= nil then
      print("Production_Revamp: Testing Mod " ..modName.. " for Version: " ..version.. ", Revamp Version " ..revampversion.. " was found.")
      if RevampChecker.check(revampversion, version) then
	    local g_revamp = getfenv(0)["FS22_A_ProductionRevamp"]
		local Revamp2 = g_revamp.Revamp
		--DebugUtil.printTableRecursively(Revamp2,"_",0,1)
	    --Production Revamp: XML Neu laden mit Revamp-Schema
	    local xmlFile = XMLFile.load("TempDesc", mod.modFile, Revamp2.XmlSchema)
	    local hasSelling = xmlFile:hasProperty("modDesc.revamp.sellFillType(0)") 
		if hasSelling then
	      xmlFile:iterate("modDesc.revamp.sellFillType", function (_, inputKey)
	        local base = xmlFile:getValue(inputKey .. "#base")
		    local fillType = xmlFile:getValue(inputKey .. "#fillType")
		    local Selltype = {}
            Selltype.base = base
            Selltype.fillType = fillType
			Selltype.modName = modName
            table.insert(Revamp2.SellFillTypes, Selltype)
		  end)
	    end
      else
        RevampChecker.warning(revampversion, version, modName)
      end
	end
  end
  xmlFile:delete()
end


RevampChecker:test()