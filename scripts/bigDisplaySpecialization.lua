--[[
Copyright (C) Achimobil & braeven, 2022

Author: Achimobil
Date: 22.07.2022
Version: 0.1.0.1

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

BigDisplaySpecialization = {
  Version = "0.1.0.0",
  Name = "BigDisplaySpecialization"
}
print(g_currentModName .. " - init " .. BigDisplaySpecialization.Name .. "(Version: " .. BigDisplaySpecialization.Version .. ")");

function BigDisplaySpecialization.prerequisitesPresent(specializations)
    return true;
  -- return SpecializationUtil.hasSpecialization(PlaceableSilo, specializations);
end

function BigDisplaySpecialization.registerEventListeners(placeableType)
  SpecializationUtil.registerEventListener(placeableType, "onLoad", BigDisplaySpecialization);
  SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", BigDisplaySpecialization);
  SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", BigDisplaySpecialization);
end

function BigDisplaySpecialization.registerFunctions(placeableType)
  SpecializationUtil.registerFunction(placeableType, "updateDisplays", BigDisplaySpecialization.updateDisplays);
end

function BigDisplaySpecialization.registerXMLPaths(schema, basePath)
  schema:setXMLSpecializationType("BigDisplay");

  schema:register(XMLValueType.NODE_INDEX, basePath .. ".silo.bigDisplays.bigDisplay(?)#node", "Display start node");
  schema:register(XMLValueType.STRING, basePath .. ".silo.bigDisplays.bigDisplay(?)#font", "Display font name");
  schema:register(XMLValueType.STRING, basePath .. ".silo.bigDisplays.bigDisplay(?)#alignment", "Display text alignment");
  schema:register(XMLValueType.FLOAT, basePath .. ".silo.bigDisplays.bigDisplay(?)#size", "Display text size");
  schema:register(XMLValueType.FLOAT, basePath .. ".silo.bigDisplays.bigDisplay(?)#scaleX", "Display text x scale");
  schema:register(XMLValueType.FLOAT, basePath .. ".silo.bigDisplays.bigDisplay(?)#scaleY", "Display text y scale");
  schema:register(XMLValueType.STRING, basePath .. ".silo.bigDisplays.bigDisplay(?)#mask", "Display text mask");
  schema:register(XMLValueType.FLOAT, basePath .. ".silo.bigDisplays.bigDisplay(?)#emissiveScale", "Display emissive scale");
  schema:register(XMLValueType.COLOR, basePath .. ".silo.bigDisplays.bigDisplay(?)#color", "Display text color");
  schema:register(XMLValueType.COLOR, basePath .. ".silo.bigDisplays.bigDisplay(?)#hiddenColor", "Display text hidden color");
  -- schema:register(XMLValueType.STRING, basePath .. ".silo.bigDisplays.siloDisplay(?)#fillType", "Filltype name for the Display to show amount");

  schema:setXMLSpecializationType();
end

function BigDisplaySpecialization:onLoad(savegame)
  self.spec_bigDisplay = {};
  local spec = self.spec_bigDisplay;
  local xmlFile = self.xmlFile;
  
  -- einfach irgendwas hin schreiben
  

  spec.bigDisplays = {};
  local i = 0;

  while true do
    local bigDisplayKey = string.format("placeable.bigDisplays.bigDisplay(%d)", i);

    if not xmlFile:hasProperty(bigDisplayKey) then
      break;
    end

    local displayNode = self.xmlFile:getValue(bigDisplayKey .. "#node", nil, self.components, self.i3dMappings);
    local fontName = self.xmlFile:getValue(bigDisplayKey .. "#font", "DIGIT"):upper();
    local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment);

    local display = {};
    local alignmentStr = self.xmlFile:getValue(bigDisplayKey .. "#alignment", "RIGHT");
    local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_RIGHT;
    local size = self.xmlFile:getValue(bigDisplayKey .. "#size", 0.13);
    local scaleX = self.xmlFile:getValue(bigDisplayKey .. "#scaleX", 1);
    local scaleY = self.xmlFile:getValue(bigDisplayKey .. "#scaleY", 1);
    local mask = self.xmlFile:getValue(bigDisplayKey .. "#mask", "000000");
    local emissiveScale = self.xmlFile:getValue(bigDisplayKey .. "#emissiveScale", 0.2);
    local color = self.xmlFile:getValue(bigDisplayKey .. "#color", {
        0.9,
        0.9,
        0.9,
        1
    }, true);
    local hiddenColor = self.xmlFile:getValue(bigDisplayKey .. "#hiddenColor", nil, true);
    display.displayNode = displayNode;
    display.formatStr, display.formatPrecision = string.maskToFormat(mask);
    display.fontMaterial = fontMaterial;
    display.characterLine = fontMaterial:createCharacterLine(display.displayNode, mask:len(), size, color, hiddenColor, emissiveScale, scaleX, scaleY, alignment);

    -- local fillTypeName = xmlFile:getValue(bigDisplayKey .. "#fillType");
    -- display.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);

    table.insert(spec.bigDisplays, display);

    i = i + 1;
  end

  -- function spec.fillLevelChangedCallback(fillType, delta)
        -- self:updateDisplays();
  -- end
end

function BigDisplaySpecialization:onFinalizePlacement(savegame)
  -- local spec = self.spec_bigDisplay;
  -- for _, sourceStorage in pairs(self.spec_silo.loadingStation:getSourceStorages()) do
    -- sourceStorage:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
  -- end
end

function BigDisplaySpecialization:onPostFinalizePlacement(savegame)
  -- self:updateDisplays();
end

function BigDisplaySpecialization:updateDisplays()
  -- local spec = self.spec_bigDisplay;
  -- local farmId = self:getOwnerFarmId();
    
  -- for _, display in pairs(spec.siloDisplays) do
    -- local fillLevel = self.spec_silo.loadingStation:getFillLevel(display.fillTypeId, farmId);
    -- local int, floatPart = math.modf(fillLevel);
    -- local value = string.format(display.formatStr, int, math.abs(math.floor(floatPart * 10^display.formatPrecision)))
    -- display.fontMaterial:updateCharacterLine(display.characterLine, value);

    -- for i = 1, #display.characterLine.characters do
      -- local charNode = display.characterLine.characters[i]
      -- setClipDistance(charNode, 500)
    -- end
  -- end
end