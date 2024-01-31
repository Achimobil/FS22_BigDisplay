--[[
Copyright (C) Achimobil, 2022-2023

Author: Achimobil
Date: 11.06.2023
Version: 0.1.4.0

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.

0.1.1.0 - 25.10.2022 - Add emptyFilltypes parameter from 112TEC
0.1.3.0 - 27.05.2023 - Add support for manure heaps and husbandaries
0.1.3.0 - 28.05.2023 - Add support for multiple columns for the display area
0.1.4.0 - 11.06.2023 - Make reconnect when current display target is sold
0.1.4.1 - 31.01.2024 - Prevent reconnect on game exit
]]

BigDisplaySpecialization = {
    Version = "0.1.4.1",
    Name = "BigDisplaySpecialization",
    displays = {}
}

function BigDisplaySpecialization.info(infoMessage, ...)
	Logging.info(g_currentModName .. " - " .. infoMessage, ...);
end

BigDisplaySpecialization.info("init %s(Version: %s)", BigDisplaySpecialization.Name, BigDisplaySpecialization.Version);

function BigDisplaySpecialization.prerequisitesPresent(specializations)
    return true;
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
    SpecializationUtil.registerFunction(placeableType, "reconnectToStorage", BigDisplaySpecialization.reconnectToStorage);
    SpecializationUtil.registerFunction(placeableType, "onStationDeleted", BigDisplaySpecialization.onStationDeleted);
end

function BigDisplaySpecialization.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", BigDisplaySpecialization.updateInfo)
end

function BigDisplaySpecialization.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("BigDisplay");

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".bigDisplays.bigDisplay(?)#upperLeftNode", "Upper left node of the screen Area");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#height", "height of the screen Area");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#width", "width of the screen Area");
    schema:register(XMLValueType.FLOAT, basePath .. ".bigDisplays.bigDisplay(?)#size", "Display text size");
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#color", "Display text color");
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#colorHybrid", "Display text color");
    schema:register(XMLValueType.COLOR, basePath .. ".bigDisplays.bigDisplay(?)#colorInput", "Display text color");
	schema:register(XMLValueType.BOOL, basePath .. ".bigDisplays.bigDisplay(?)#emptyFilltypes", "Display empty Filltypes", false)
	schema:register(XMLValueType.INT, basePath .. ".bigDisplays.bigDisplay(?)#columns", "Number of columns the display is splittet to", 1)
    
    schema:setXMLSpecializationType();
end

function BigDisplaySpecialization:onLoad(savegame)
    self.spec_bigDisplay = {};
    local spec = self.spec_bigDisplay;
    local xmlFile = self.xmlFile;
    
    spec.bigDisplays = {};
    spec.changedColors = {}
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
        local colorHybrid = self.xmlFile:getValue(bigDisplayKey .. "#colorHybrid", {
        0.5,
        0.7,
        0.0,
        1
        }, true);
        local colorInput = self.xmlFile:getValue(bigDisplayKey .. "#colorInput", {
        0.0,
        0.7,
        0.3,
        1
        }, true);
        local emptyFilltypes = xmlFile:getValue(bigDisplayKey .. "#emptyFilltypes", false)
        local columns = xmlFile:getValue(bigDisplayKey .. "#columns", 1)
		
        local bigDisplay = {};
        bigDisplay.color = color;
        bigDisplay.colorHybrid = colorHybrid;
        bigDisplay.colorInput = colorInput;
        bigDisplay.textSize = size;
        bigDisplay.displayLines = {};
        bigDisplay.currentPage = 1;
        bigDisplay.lastPageTime = 0;
        bigDisplay.nodeId = upperLeftNode;
        bigDisplay.textDrawDistance = 30;
        bigDisplay.enmptyFilltypes = emptyFilltypes;
        bigDisplay.columns = columns;
		
		-- breite pro Spalte berechnen
		local columnWidth = (width - (0.05 * (columns - 1))) / columns;
		
		-- schleife pro spalte
		for currentColumn = 1, columns do
		
			-- linker startpunkt für die Schrift
			local leftStart = 0 + ((columnWidth + 0.05) * (currentColumn - 1))
			local rightStart = width - ((columnWidth + 0.05) * (columns - currentColumn))
		
			-- Mögliche zeilen anhand der Größe erstellen
			local lineHeight = size;
			-- local x, y, z = getWorldTranslation(upperLeftNode)
			local rx, ry, rz = getWorldRotation(upperLeftNode)
			for currentY = -size/2, -height-(size/2), -lineHeight do
			
				local displayLine = {};
				displayLine.text = {}
				displayLine.value = {}
				
				local x,y,z = localToWorld(upperLeftNode, leftStart, currentY, 0);
				displayLine.text.x = x;
				displayLine.text.y = y;
				displayLine.text.z = z;
				
				local x,y,z = localToWorld(upperLeftNode, rightStart, currentY, 0);
				displayLine.value.x = x;
				displayLine.value.y = y;
				displayLine.value.z = z;
				
				displayLine.rx = rx;
				displayLine.ry = ry;
				displayLine.rz = rz;
				
				table.insert(bigDisplay.displayLines, displayLine);
			end
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
    if spec.loadingStationToUse == nil then 
        return;
    end
end

function BigDisplaySpecialization:onPostFinalizePlacement(savegame)
    table.insert(BigDisplaySpecialization.displays, self);
    self:reconnectToStorage();
end

function BigDisplaySpecialization:reconnectToStorage(savegame)
    local spec = self.spec_bigDisplay;
    
    if spec.loadingStationToUse ~= nil then 
        local storages = spec.loadingStationToUse.sourceStorages or spec.loadingStationToUse.targetStorages;
        for _, sourceStorage in pairs(storages) do
            sourceStorage:removeFillLevelChangedListeners(spec.fillLevelChangedCallback);
        end
		spec.loadingStationToUse:removeDeleteListener(self, "onStationDeleted")
        spec.loadingStationToUse = nil;
    end
    
    if not self.isClient then 
        return;
    end
    
    -- find the storage closest to me
    local currentLoadingStation = nil;
    local currentDistance = math.huge;
    local usedProduction = nil;
    for _, storage in pairs(g_currentMission.storageSystem:getStorages()) do
        -- wenn tierstall, dann ignorieren
        local ignore = false;
        
        -- loadingStation oder unloadingStation aus der liste die jeweils erste benutzen
        local loadingStation = nil;
        
        for j, loadingSt in pairs (storage.loadingStations) do
            if loadingStation == nil then
                loadingStation = loadingSt;
            end
        end
        
        if loadingStation == nil then
            for j, unloadingSt in pairs (storage.unloadingStations) do
                if loadingStation == nil then
                    loadingStation = unloadingSt;
                end
            end
        end
                
        if loadingStation ~= nil then
            -- entfernung wie messen?
            local distance = BigDisplaySpecialization:getDistance(loadingStation, self.position.x, self.position.y, self.position.z)
            if distance < currentDistance and not ignore then
                currentDistance = distance;
                currentLoadingStation = loadingStation;
            end
        end
    end
    
    -- auch produktionen durchsuchen nach dem richtigen storage, die stehen nicht im storage system
    local farmId = self:getOwnerFarmId();
    
    for index, productionPoint in ipairs(g_currentMission.productionChainManager:getProductionPointsForFarmId(farmId)) do
        
        local loadingStation = productionPoint.loadingStation;
        if loadingStation == nil then
            loadingStation = productionPoint.unloadingStation;
        end
        if loadingStation ~= nil then
        
            local distance = BigDisplaySpecialization:getDistance(loadingStation, self.position.x, self.position.y, self.position.z)
            if distance < currentDistance then
                currentDistance = distance;
                currentLoadingStation = loadingStation;
                usedProduction = productionPoint;
            end
        end
		
	end
    
    if currentLoadingStation == nil then
		BigDisplaySpecialization.info("no Loading Station found");
        return;
    end

    spec.loadingStationToUse = currentLoadingStation;
    self:updateDisplayData();
    
-- BigDisplaySpecialization.info("spec.loadingStationToUse")
-- DebugUtil.printTableRecursively(spec.loadingStationToUse,"_",0,2)

    -- farben festlegen. Input, output oder beides?
    if usedProduction ~= nil then
        for inputFillTypeIndex in pairs(usedProduction.inputFillTypeIds) do
            if spec.changedColors[inputFillTypeIndex] == nil then
                spec.changedColors[inputFillTypeIndex] = {isInput = false, isOutput = false};
            end
            spec.changedColors[inputFillTypeIndex].isInput = true;
        end
        for outputFillTypeIndex in pairs(usedProduction.outputFillTypeIds) do
            if spec.changedColors[outputFillTypeIndex] == nil then
                spec.changedColors[outputFillTypeIndex] = {isInput = false, isOutput = false};
            end
            spec.changedColors[outputFillTypeIndex].isOutput = true;
        end
        for fillTypeIndex, changedColor in pairs(spec.changedColors) do
            if changedColor.isInput then
                if changedColor.isOutput then
                    changedColor.color = spec.bigDisplays[1].colorHybrid;
                else
                    changedColor.color = spec.bigDisplays[1].colorInput;
                end
            else
                changedColor.color = spec.bigDisplays[1].color;
            end
        end
    end
	
	-- Futter bei Tierställen hinzufügen einfärben
	if spec.loadingStationToUse.owningPlaceable ~= nil and spec.loadingStationToUse.owningPlaceable.spec_husbandryFood ~= nil then
		local spec = self.spec_bigDisplay;
		for fillType, fillLevel in pairs(spec.loadingStationToUse.owningPlaceable.spec_husbandryFood.fillLevels) do
            if spec.changedColors[fillType] == nil then
                spec.changedColors[fillType] = {isInput = false, isOutput = false};
            end
            spec.changedColors[fillType].color = spec.bigDisplays[1].colorInput;
		end
	end
    
    local storages = spec.loadingStationToUse.sourceStorages or spec.loadingStationToUse.targetStorages;
    
    for _, sourceStorage in pairs(storages) do
        sourceStorage:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
    end
	
	spec.loadingStationToUse:addDeleteListener(self, "onStationDeleted")
end

function BigDisplaySpecialization:onStationDeleted(station)
	
    if g_currentMission.isExitingGame == nil then
		BigDisplaySpecialization.info("Exiting game, prevent reconnect on station delete");
        return;
    end
	
	self:reconnectToStorage();
end

function BigDisplaySpecialization:onDelete()
    table.removeElement(BigDisplaySpecialization.displays, self);
end

function BigDisplaySpecialization:getDistance(loadingStation, x, y, z)
-- BigDisplaySpecialization.info("placable")
-- DebugUtil.printTableRecursively(placable,"_",0,2)
	if loadingStation ~= nil then
		local tx, ty, tz = getWorldTranslation(loadingStation.rootNode)

        if tx == nil or ty == nil or tz == nil then
            -- fehlerhafte loadingstations deren position nicht ermitteln kann, ignorieren wir hier
            return math.huge
        end

		return MathUtil.vector3Length(x - tx, y - ty, z - tz)
	end

	return math.huge
end

function BigDisplaySpecialization:updateDisplayData()
    local spec = self.spec_bigDisplay;
    if spec == nil or spec.loadingStationToUse == nil then 
        return;
    end
    
    local farmId = self:getOwnerFarmId();
  
    for _, bigDisplay in pairs(spec.bigDisplays) do
        -- in jede line schreiben, was angezeigt werden soll
        -- hier eventuell filtern anhand von xml einstellungen?
        -- möglich per filltype liste fstzulegen was in welcher reihenfolge angezeigt wird, sinnvoll?
        -- sortieren per XML einstellung?
        bigDisplay.lineInfos = {};
        for fillTypeId, fillLevel in pairs(BigDisplaySpecialization:getAllFillLevels(spec.loadingStationToUse, farmId)) do
            local lineInfo = {};
            lineInfo.fillTypeId = fillTypeId;
            lineInfo.title = g_fillTypeManager:getFillTypeByIndex(fillTypeId).title;
            local myFillLevel = Utils.getNoNil(fillLevel, 0);
            lineInfo.fillLevel = g_i18n:formatNumber(myFillLevel, 0);
			
			if bigDisplay.enmptyFilltypes then
				table.insert(bigDisplay.lineInfos, lineInfo);
			else
				-- erst mal nur anzeigen wo auch was da ist?
				if(myFillLevel ~= 0) then 
					table.insert(bigDisplay.lineInfos, lineInfo);
				end 
			end
        end
		
        table.sort(bigDisplay.lineInfos,compLineInfos)
    end
    
    local line = 1;
end

function BigDisplaySpecialization:getAllFillLevels(station, farmId)
	local fillLevels = {}
    
    local storages = station.sourceStorages or station.targetStorages;

	for _, sourceStorage in pairs(storages) do
		if station:hasFarmAccessToStorage(farmId, sourceStorage) then
			for fillType, fillLevel in pairs(sourceStorage:getFillLevels()) do
				fillLevels[fillType] = Utils.getNoNil(fillLevels[fillType], 0) + fillLevel
			end
		end
	end
	
	-- Futter bei Tierställen hinzufügen
	if station.owningPlaceable ~= nil and station.owningPlaceable.spec_husbandryFood ~= nil then
		for fillType, fillLevel in pairs(station.owningPlaceable.spec_husbandryFood.fillLevels) do
			fillLevels[fillType] = Utils.getNoNil(fillLevels[fillType], 0) + fillLevel;
		end
	end

	return fillLevels
end

function compLineInfos(w1,w2)
    return w1.title < w2.title;
end

function BigDisplaySpecialization:updateDisplays(dt)
    local spec = self.spec_bigDisplay;
    if spec == nil or spec.loadingStationToUse == nil then 
        return;
    end
    
    if not self.isClient then 
        return;
    end
    
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    
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
    
                    local color = spec.bigDisplays[1].color;
                    if spec.changedColors[lineInfo.fillTypeId] ~= nil then
                        color = spec.changedColors[lineInfo.fillTypeId].color;
                    end
    
                    setTextColor(color[1], color[2], color[3], color[4])
    
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


function BigDisplaySpecialization:updateInfo(superFunc, infoTable)
    local spec = self.spec_bigDisplay;

	local owningFarm = g_farmManager:getFarmById(self:getOwnerFarmId())

	table.insert(infoTable, {
		title = g_i18n:getText("fieldInfo_ownedBy"),
		text = owningFarm.name
	})

    if (spec.loadingStationToUse ~= nil) then
        table.insert(infoTable, {
            title = g_i18n:getText("bigDisplay_connected_with"),
            text = spec.loadingStationToUse:getName();
        })
    end
end

addModEventListener(BigDisplaySpecialization)

function BigDisplaySpecialization:onStartMission()
    -- update faken, muss auch entfernt werden beim löschen, wenn es so klappt
    for _, display in pairs(BigDisplaySpecialization.displays) do
        display:reconnectToStorage();
    end
end
Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, BigDisplaySpecialization.onStartMission)