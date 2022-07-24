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
	SpecializationUtil.registerEventListener(placeableType, "onDelete", BigDisplaySpecialization)
end

function BigDisplaySpecialization.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "updateDisplays", BigDisplaySpecialization.updateDisplays);
    SpecializationUtil.registerFunction(placeableType, "updateDisplayData", BigDisplaySpecialization.updateDisplayData);
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
        local bigDisplay = {};
        bigDisplay.color = color;
        bigDisplay.textSize = size;
        bigDisplay.displayLines = {};
        bigDisplay.currentPage = 1;
        bigDisplay.lastPageTime = 0;
        bigDisplay.nodeId = upperLeftNode;
        bigDisplay.textDrawDistance = 30;
        
        -- Mögliche zeilen anhand der Größe erstellen
        local lineHeight = size;
        -- local x, y, z = getWorldTranslation(upperLeftNode)
        local rx, ry, rz = getWorldRotation(upperLeftNode)
        for currentY = -size/2, -height-(size/2), -lineHeight do
        
            local displayLine = {};
            displayLine.text = {}
            displayLine.value = {}
            
            local x,y,z = localToWorld(upperLeftNode, 0, currentY, 0);
            displayLine.text.x = x;
            displayLine.text.y = y;
            displayLine.text.z = z;
            
            local x,y,z = localToWorld(upperLeftNode, width, currentY, 0);
            displayLine.value.x = x;
            displayLine.value.y = y;
            displayLine.value.z = z;
            
            displayLine.rx = rx;
            displayLine.ry = ry;
            displayLine.rz = rz;
            
            table.insert(bigDisplay.displayLines, displayLine);
        end
        
        table.insert(spec.bigDisplays, bigDisplay);
                
        i = i + 1;
    end

    function spec.fillLevelChangedCallback(fillType, delta)
        self:updateDisplayData();
    end
end

function BigDisplaySpecialization:onFinalizePlacement(savegame)
    local spec = self.spec_bigDisplay;
    if spec.storageToUse == nil then 
        return;
    end
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
    self:updateDisplayData();
    
    spec.storageToUse:addFillLevelChangedListeners(spec.fillLevelChangedCallback);

    table.insert(BigDisplaySpecialization.displays, self);
end

function BigDisplaySpecialization:onDelete()
    table.removeElement(BigDisplaySpecialization.displays, self);
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

function BigDisplaySpecialization:updateDisplayData()
    local spec = self.spec_bigDisplay;
    if spec == nil or spec.storageToUse == nil then 
        return;
    end
  
    for _, bigDisplay in pairs(spec.bigDisplays) do
        -- in jede line schreiben, was angezeigt werden soll
        -- hier eventuell filtern anhand von xml einstellungen?
        -- möglich per filltype liste fstzulegen was in welcher reihenfolge angezeigt wird, sinnvoll?
        -- sortieren per XML einstellung?
        bigDisplay.lineInfos = {};
        for fillTypeId, fillLevel in pairs(spec.storageToUse:getFillLevels()) do
            local lineInfo = {};
            lineInfo.title = g_fillTypeManager:getFillTypeByIndex(fillTypeId).title;
            local myFillLevel = Utils.getNoNil(fillLevel, 0);
            lineInfo.fillLevel = g_i18n:formatNumber(myFillLevel, 0);
            
            -- erst mal nur anzeigen wo auch was da ist?
            -- if(myFillLevel ~= 0) then
                table.insert(bigDisplay.lineInfos, lineInfo);
            -- end
        end
        
        table.sort(bigDisplay.lineInfos,compLineInfos)
    end
    
    local line = 1;
end

function compLineInfos(w1,w2)
    return w1.title < w2.title;
end

function BigDisplaySpecialization:updateDisplays(dt)
    local spec = self.spec_bigDisplay;
    if spec == nil or spec.storageToUse == nil then 
        return;
    end
    
    if not self.isClient then 
        return;
    end
    
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextColor(spec.bigDisplays[1].color[1], spec.bigDisplays[1].color[2], spec.bigDisplays[1].color[3], spec.bigDisplays[1].color[4])
    
    for _, bigDisplay in pairs(spec.bigDisplays) do
    
        -- entfernung zum display ermitteln damit es nicht immer gerendert wird
        -- display position nur ein mal ermitteln
        if bigDisplay.worldTranslation == nil then
            bigDisplay.worldTranslation = {getWorldTranslation(bigDisplay.nodeId)};
        end
        -- position des spielers
        local x, z = 0, 0;
        if g_currentMission.controlPlayer then
            x, _, z = getWorldTranslation(g_currentMission.player.rootNode);
        elseif g_currentMission.controlledVehicle ~= nil then
            x, _, z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode);
        end
    
        if MathUtil.vector2Length(x - bigDisplay.worldTranslation[1], z - bigDisplay.worldTranslation[3]) < bigDisplay.textDrawDistance then
            -- paging
            local pageOffset = 0;
            bigDisplay.lastPageTime = bigDisplay.lastPageTime + dt;
            local pages = math.ceil(#bigDisplay.lineInfos / #bigDisplay.displayLines);
            if bigDisplay.lastPageTime >= 5000 then
                if bigDisplay.currentPage >= pages then
                    bigDisplay.currentPage = 1;
                else
                    bigDisplay.currentPage = bigDisplay.currentPage + 1;
                end
                bigDisplay.lastPageTime = 0;
            end
            
            local pageOffset = (bigDisplay.currentPage - 1) * #bigDisplay.displayLines;
            for index, displayLine in pairs(bigDisplay.displayLines) do
                local lineIndex = index + pageOffset;
                if bigDisplay.lineInfos[lineIndex] ~= nil then
                    local lineInfo = bigDisplay.lineInfos[lineIndex];
                    
                    setTextAlignment(RenderText.ALIGN_LEFT)
                    renderText3D(displayLine.text.x, displayLine.text.y, displayLine.text.z, displayLine.rx, displayLine.ry, displayLine.rz, spec.bigDisplays[1].textSize, lineInfo.title)
                    setTextAlignment(RenderText.ALIGN_RIGHT)
                    renderText3D(displayLine.value.x, displayLine.value.y, displayLine.value.z, displayLine.rx, displayLine.ry, displayLine.rz, spec.bigDisplays[1].textSize, lineInfo.fillLevel)
                end
            end
        end
    end
end

function BigDisplaySpecialization:update(dt)
    -- update faken, muss auch entfernt werden beim löschen, wenn es so klappt
    for _, display in pairs(BigDisplaySpecialization.displays) do
        display:updateDisplays(dt);
    end
end

addModEventListener(BigDisplaySpecialization)