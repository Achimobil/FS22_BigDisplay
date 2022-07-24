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

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".bigDisplays.bigDisplay(?)#upperLeftNode", "Upper left node of the screen Area");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#height", "height of the screen Area");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#width", "width of the screen Area");
    
    
    schema:register(XMLValueType.STRING, basePath .. ".bigDisplays.bigDisplay(?)#font", "Display font name");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#size", "Display text size");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#scaleX", "Display text x scale");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#scaleY", "Display text y scale");
    schema:register(XMLValueType.STRING, basePath .. ".bigDisplays.bigDisplay(?)#mask", "Display text mask");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#emissiveScale", "Display emissive scale");
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#color", "Display text color");
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#hiddenColor", "Display text hidden color");
    -- schema:register(XMLValueType.STRING, basePath .. ".bigDisplays.siloDisplay(?)#fillType", "Filltype name for the Display to show amount");

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

        local upperLeftNode = self.xmlFile:getValue(bigDisplayKey .. "#upperLeftNode", nil, self.components, self.i3dMappings);
        local height = self.xmlFile:getValue(bigDisplayKey .. "#height", 1);
        local width = self.xmlFile:getValue(bigDisplayKey .. "#width", 1);

        -- display general stuff
        local fontName = self.xmlFile:getValue(bigDisplayKey .. "#font", "GENERIC"):upper();
        local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment);

        local size = self.xmlFile:getValue(bigDisplayKey .. "#size", 0.11);
        local scaleX = self.xmlFile:getValue(bigDisplayKey .. "#scaleX", 1);
        local scaleY = self.xmlFile:getValue(bigDisplayKey .. "#scaleY", 1);
        local mask = self.xmlFile:getValue(bigDisplayKey .. "#mask", "000000000000000");
        local emissiveScale = self.xmlFile:getValue(bigDisplayKey .. "#emissiveScale", 0.5);
        local color = self.xmlFile:getValue(bigDisplayKey .. "#color", {
        0.6,
        0.9,
        0.6,
        1
        }, true);
        local hiddenColor = self.xmlFile:getValue(bigDisplayKey .. "#hiddenColor", nil, true);
        
        -- for 2 childs create one line left and right alligned
        local numChildren = getNumOfChildren(upperLeftNode)

        for i = 0, numChildren - 2, 2 do
            local textNodeId = getChildAt(upperLeftNode, i)
            local numberNodeId = getChildAt(upperLeftNode, i+1)

            -- move to lower
            local sizeToUse = size + 0.02;
            local lowerToSize = i*(sizeToUse/2) + sizeToUse;
            
            local x,y,z = localToWorld(textNodeId, 0, -lowerToSize, 0);
            setWorldTranslation(textNodeId, x, y, z)
            local x,y,z = localToWorld(numberNodeId, width, -lowerToSize, 0);
            setWorldTranslation(numberNodeId, x, y, z)
            
            local display = {};
            display.textNodeId = textNodeId;
            display.numberNodeId = numberNodeId;
            display.formatStr, display.formatPrecision = string.maskToFormat(mask);
            display.fontMaterial = fontMaterial;
            display.textLine = fontMaterial:createCharacterLine(display.textNodeId, 15, size, color, hiddenColor, emissiveScale, scaleX, scaleY, RenderText.ALIGN_LEFT);
            display.numberLine = fontMaterial:createCharacterLine(display.numberNodeId, 8, size, color, hiddenColor, emissiveScale, scaleX, scaleY, RenderText.ALIGN_RIGHT);
            if(lowerToSize <= height) then
                table.insert(spec.bigDisplays, display);
            end
            
        end

        -- local fillTypeName = xmlFile:getValue(bigDisplayKey .. "#fillType");
        -- display.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);


        i = i + 1;
    end

    function spec.fillLevelChangedCallback(fillType, delta)
        self:updateDisplays();
    end
end

function BigDisplaySpecialization:onFinalizePlacement(savegame)
    local spec = self.spec_bigDisplay;
    if spec.storageToUse == nil then 
        return;
    end
    
    -- for _, sourceStorage in pairs(self.spec_silo.loadingStation:getSourceStorages()) do
        -- spec.storageToUse:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
    -- end
end

function BigDisplaySpecialization:onPostFinalizePlacement(savegame)
    local spec = self.spec_bigDisplay;
    
    -- find the storage closest to me
    local currentStorage = nil;
    local currentDistance = math.huge;
    for _, storage in pairs(g_currentMission.storageSystem:getStorages()) do
        -- entfernung wie messen?
        local distance = BigDisplaySpecialization:getDistance(storage, self.position.x, self.position.y, self.position.z)
        if distance < currentDistance then
            currentDistance = distance;
            currentStorage = storage;
        end
    end
    
    -- auch produktionen durchsuchen nach dem richtigen storage, die stehen nicht im storage system
    local farmId = self:getOwnerFarmId();
    
    
    for index, productionPoint in ipairs(g_currentMission.productionChainManager:getProductionPointsForFarmId(farmId)) do
        local distance = BigDisplaySpecialization:getDistance(productionPoint.storage, self.position.x, self.position.y, self.position.z)
        if distance < currentDistance then
            currentDistance = distance;
            currentStorage = productionPoint.storage;
        end
		
	end
    
    if currentStorage == nil then
        print("no Storage found");
        return;
    end

    spec.storageToUse = currentStorage;
    self:updateDisplays();
    
    spec.storageToUse:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
end

function BigDisplaySpecialization:getDistance(storage, x, y, z)
-- print("placable")
-- DebugUtil.printTableRecursively(placable,"_",0,2)
	if storage ~= nil then
		local tx, ty, tz = getWorldTranslation(storage.rootNode)

		return MathUtil.vector3Length(x - tx, y - ty, z - tz)
	end

	return math.huge
end

function BigDisplaySpecialization:updateDisplays()
    local spec = self.spec_bigDisplay;
    if spec.storageToUse == nil then 
        return;
    end
  
    local line = 1;
    for fillTypeId, fillLevel in pairs(spec.storageToUse:getFillLevels()) do
    
        if spec.bigDisplays[line] == nil then
            return; -- mehr Zeilen haben wir nicht
        end
        
        local fillLevel = Utils.getNoNil(fillLevel, 0);
        
        -- if fillLevel >= 1 then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId);
                        
            local textLine = string.format("%15s", string.sub(fillType.title, 1, 15))
            spec.bigDisplays[line].fontMaterial:updateCharacterLine(spec.bigDisplays[line].textLine, textLine);
            
            local numberLine = string.format("%8s", g_i18n:formatNumber(fillLevel, 0))
            spec.bigDisplays[line].fontMaterial:updateCharacterLine(spec.bigDisplays[line].numberLine, numberLine);
            
            line = line + 1;
        -- end
    end

    -- local textLine = string.format("%-15s", "DiesIstEinVileZuLangerText")
    -- spec.bigDisplays[1].fontMaterial:updateCharacterLine(spec.bigDisplays[1].textLine, textLine);
    -- local textLine = string.format("%15s", "4812")
    -- spec.bigDisplays[1].fontMaterial:updateCharacterLine(spec.bigDisplays[1].numberLine, textLine);
    
    -- local textLine = string.format("%-15s", "Hallo Achim")
    -- spec.bigDisplays[2].fontMaterial:updateCharacterLine(spec.bigDisplays[2].textLine, textLine);
    -- local textLine = string.format("%15s", "12345678901234567890")
    -- spec.bigDisplays[2].fontMaterial:updateCharacterLine(spec.bigDisplays[2].numberLine, textLine);

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