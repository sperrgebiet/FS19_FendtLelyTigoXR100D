-- Inspired by the FS17 version. Kudos to Ziuta and 50keda, as they came up with it initially. Seems the history goes back to FS15 even
--
-- This FS19 version was writtey by sperrgebiet
--
-- Unlike others I see the meaning in mods that others can learn, expand and improve them. So feel free to use this in your own mods, 
-- add stuff to it, improve it. Your own creativity is the limit ;) If you want to mention me in the credits fine. If not, I'll live happily anyway:P
--
-- To add/change the available capacities add the following section in your <modVehicle>.xml
--
-- <variableCapacity>54000, 75000, 100000</variableCapacity>
-- 
-- Add it as specilication and you're good to go.
-- As you can see in the code, it just changes the capacity of the first fillUnit. At a later stage this might get changed. But I think for the majority of use cases,
-- especially for forageWagons this is fine

VariableCapacity = {}
VariableCapacity.eventName = {}
VariableCapacity.ModName = g_currentModName
VariableCapacity.ModDirectory = g_currentModDirectory
VariableCapacity.Version = "1.0.0.0"

VariableCapacity.debug = fileExists(VariableCapacity.ModDirectory ..'debug')

print(string.format('VariableCapacity v%s - DebugMode %s)', VariableCapacity.Version, tostring(VariableCapacity.debug)))

addModEventListener(VariableCapacity)

function VariableCapacity:dp(val, fun, msg) -- debug mode, write to log
	if not VariableCapacity.debug then
		return;
	end

	if msg == nil then
		msg = ' ';
	else
		msg = string.format(' msg = [%s] ', tostring(msg));
	end

	local pre = 'VariableCapacity DEBUG:';

	if type(val) == 'table' then
		--if #val > 0 then
			print(string.format('%s BEGIN Printing table data: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
			DebugUtil.printTableRecursively(val, '.', 0, 3);
			print(string.format('%s END Printing table data: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
		--else
		--	print(string.format('%s Table is empty: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
		--end
	else
		print(string.format('%s [%s]%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
	end
end

function VariableCapacity.prerequisitesPresent(specializations)
    return true;
end

function VariableCapacity.registerEventListeners(vehicleType)
	local functionNames = {	"onRegisterActionEvents", "onDraw", "onLoad", "saveToXMLFile" }
	for _, functionName in ipairs(functionNames) do
		SpecializationUtil.registerEventListener(vehicleType, functionName, VariableCapacity)
	end
end

function VariableCapacity:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	if self.isClient then
		VariableCapacity.actionEvents = {}
		if isSelected then
			local _, actionEventId = self:addActionEvent(VariableCapacity.actionEvents, 'toggleCapacity', self, VariableCapacity.action_toggleCapacity, false, true, false, true, nil)
		end		
	end
end

function VariableCapacity:action_toggleCapacity(actionName, keyStatus, arg3, arg4, arg5)
	
	-- Just go through all the hassle when the object is empty
	if self:getFillUnitFillLevel(1) == 0 then
		-- Actually we should always have a valid capacity set. So make sure that's the case and that we then change to the next capacity from fromg
		local capacity = self:getFillUnitCapacity(1)
		local currIndex = VariableCapacity:getIndexByValue(VariableCapacity.capacities, capacity)
		local nextIndex = 1
		
		if currIndex ~= nil then
			if (currIndex + 1) <= #VariableCapacity.capacities then
				nextIndex = currIndex + 1
			end
		end
		
		capacity = VariableCapacity.capacities[nextIndex]
		VariableCapacity:setCapacity(self, capacity, false)
	else
		g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[VariableCapacity.ModName].texts.WarningNotEmpty, 5000)
	end
end

function VariableCapacity:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	g_currentMission:addExtraPrintText(g_i18n.modEnvironments[VariableCapacity.ModName].texts.currentCapacity .. string.format(" : %d",  self:getFillUnitCapacity(1)))
end

function VariableCapacity:onLoad(savegame)
	if savegame ~= nil then
		local xmlFile = savegame.xmlFile;
		local key = savegame.key..".variableCapacity";
		local savedCapacity = getXMLInt(xmlFile, key)
		if savedCapacity ~= nil then
			VariableCapacity:setCapacity(self, savedCapacity, true)
		end
	end
	
	if hasXMLProperty(self.xmlFile, 'vehicle.variableCapacity') then
		local availableCapacities = getXMLString(self.xmlFile, "vehicle.variableCapacity")
		local capacities = {}
		for str in string.gmatch(availableCapacities, '([^,]+)') do
		   table.insert(capacities, tonumber(str))
		end
		
		if #capacities > 0 then 
			table.sort(capacities)
			VariableCapacity.capacities = capacities
			VariableCapacity.varCapacity = self:getFillUnitCapacity(1)
		end
	end
end

function VariableCapacity:saveToXMLFile(xmlFile, key)
	--As the game engine would add the modname to 'key' we've to get rid of it
	local key = key:gsub(string.format("%s.", VariableCapacity.ModName), "")
	setXMLInt(xmlFile, key, self:getFillUnitCapacity(1))
end

function VariableCapacity:setCapacity(obj, capacity, noEventSend)

	obj:setFillUnitCapacity(1, capacity)
	VarCapSetCapacityEvent.sendEvent(obj, capacity, noEventSend)

    -- create fill units
    for _, mapping in ipairs(obj.spec_fillVolume.fillUnitFillVolumeMapping) do
        for _, fillVolume in ipairs(mapping.fillVolumes) do
            fillVolume.fillUnitFactor = fillVolume.fillUnitFactor / mapping.sumFactors
        end
    end	
	
	for _, fillVolume in ipairs(obj.spec_fillVolume.volumes) do
        local fillUnitCap = obj:getFillUnitCapacity(fillVolume.fillUnitIndex)
        local fillVolumeCapacity = fillUnitCap * fillVolume.fillUnitFactor		
		fillVolume.volume = createFillPlaneShape(fillVolume.baseNode, "fillVolumeScript", fillVolumeCapacity, fillVolume.maxDelta, fillVolume.maxSurfaceAngle, fillVolume.maxPhysicalSurfaceAngle, fillVolume.maxSubDivEdgeLength, fillVolume.allSidePlanes)						
		setVisibility(fillVolume.volume, false)
		for i=#fillVolume.deformers, 1, -1 do
			local deformer = fillVolume.deformers[i]
			deformer.polyline = findPolyline(fillVolume.volume, deformer.posX, deformer.posZ)
			if deformer.polyline == nil and deformer.polyline ~= -1 then
				print("Warning: Could not find 'polyline' for '"..tostring(getName(deformer.node)).."' in '"..obj.configFileName.."'")
				table.remove(fillVolume.deformers, i)
			end
		end		
		link(fillVolume.baseNode, fillVolume.volume)
	end

end

function VariableCapacity:getIndexByValue(tbl, val)
	for k, v in ipairs(tbl) do
		if v == val then
			return k
		end
	end
end

--
-- MP Stuff
--

VarCapSetCapacityEvent = {}
VarCapSetCapacityEvent_mt = Class(VarCapSetCapacityEvent, Event)

InitEventClass(VarCapSetCapacityEvent, "VarCapSetCapacityEvent")

function VarCapSetCapacityEvent:emptyNew()
    local self = Event:new(VarCapSetCapacityEvent_mt)
	self.claasName = "VarCapSetCapacityEvent"
    return self
end

function VarCapSetCapacityEvent:new(object, varCapacity)
    local self = VarCapSetCapacityEvent:emptyNew()
    self.object = object
	self.varCapacity = varCapacity
    return self
end


function VarCapSetCapacityEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.varCapacity = streamReadInt32(streamId)
	self:run(connection)
end

function VarCapSetCapacityEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt32(streamId, self.varCapacity)
end

function VarCapSetCapacityEvent:run(connection)
	if self.object ~= nil and self.varCapacity ~= nil then
		VariableCapacity:setCapacity(self.object, self.varCapacity, true)
	end
    if not connection:getIsServer() then
        g_server:broadcastEvent(VarCapSetCapacityEvent:new(self.object, self.varCapacity), nil, connection, self.object)
    end
end

function VarCapSetCapacityEvent.sendEvent(vehicle, capacity, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(VarCapSetCapacityEvent:new(vehicle, capacity), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(VarCapSetCapacityEvent:new(vehicle, capacity))
		end
	end
end