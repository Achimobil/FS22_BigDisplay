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
    Name = "BigDisplaySpecialization",
    displays = {}
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
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#color", "Display text color");
    
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
        local size = self.xmlFile:getValue(bigDisplayKey .. "#size", 0.11);
        local color = self.xmlFile:getValue(bigDisplayKey .. "#color", {
        0.0,
        0.9,
        0.0,
        1
        }, true);
        spec.color = color;
                
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
            display.textSize = size;
            display.numberNodeId = numberNodeId;
            if(lowerToSize <= height) then
                table.insert(spec.bigDisplays, display);
            end
            
        end

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

    table.insert(BigDisplaySpecialization.displays, self);
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
    if spec == nil or spec.storageToUse == nil then 
        return;
    end
    -- print("BigDisplaySpecialization:updateDisplays");
  
    --  hier tabelle zum anzeigen erzeugen, anzeige selbst in anderer methode machen
    local line = 1;
    for fillTypeId, fillLevel in pairs(spec.storageToUse:getFillLevels()) do
    
        if spec.bigDisplays[line] == nil then
            return; -- mehr Zeilen haben wir nicht
        end
        
        local fillLevel = Utils.getNoNil(fillLevel, 0);
        
        -- if fillLevel >= 1 then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId);
                        
            -- test mit rendern, wenn geht, dann auslesen und anzeigen trennen
            local x, y, z = getWorldTranslation(spec.bigDisplays[line].textNodeId)
            local rx, ry, rz = getWorldRotation(spec.bigDisplays[line].textNodeId)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(spec.color[1], spec.color[2], spec.color[3], spec.color[4])
            renderText3D(x, y, z, rx, ry, rz, spec.bigDisplays[line].textSize, fillType.title)
            
            local x, y, z = getWorldTranslation(spec.bigDisplays[line].numberNodeId)
            local rx, ry, rz = getWorldRotation(spec.bigDisplays[line].numberNodeId)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextColor(spec.color[1], spec.color[2], spec.color[3], spec.color[4])
            renderText3D(x, y, z, rx, ry, rz, spec.bigDisplays[line].textSize, g_i18n:formatNumber(fillLevel, 0))
            
            line = line + 1;
        -- end
    end
end

function BigDisplaySpecialization:update(dt)
    -- print("BigDisplaySpecialization:update");
    -- update faken, muss auch entfernt werden beim löschen, wenn es so klappt
    for _, display in pairs(BigDisplaySpecialization.displays) do
        display:updateDisplays();
    end
end

addModEventListener(BigDisplaySpecialization)