-- ============================================================= --
-- Universal Autoload MOD - MANAGER
-- ============================================================= --

-- manager
UniversalAutoloadManager = {}
addModEventListener(UniversalAutoloadManager)

-- specialisation
g_specializationManager:addSpecialization('universalAutoload', 'UniversalAutoload', Utils.getFilename('UniversalAutoload.lua', g_currentModDirectory), "")

for vehicleName, vehicleType in pairs(g_vehicleTypeManager.types) do
    -- Anything with tension belts could potentially require autoload
    if SpecializationUtil.hasSpecialization(TensionBelts, vehicleType.specializations) then
        g_vehicleTypeManager:addSpecialization(vehicleName, g_currentModName .. '.universalAutoload')
		-- print("  UAL INSTALLED: "..vehicleName)
    end
end

-- variables
UniversalAutoload.userSettingsFile = "modSettings/UniversalAutoload.xml"

-- tables
UniversalAutoload.ACTIONS = {
	["TOGGLE_LOADING"]        = "UNIVERSALAUTOLOAD_TOGGLE_LOADING",
	["UNLOAD_ALL"]            = "UNIVERSALAUTOLOAD_UNLOAD_ALL",
	["TOGGLE_TIPSIDE"]        = "UNIVERSALAUTOLOAD_TOGGLE_TIPSIDE",
	["TOGGLE_FILTER"]         = "UNIVERSALAUTOLOAD_TOGGLE_FILTER",
	["CYCLE_MATERIAL_FW"]     = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_FW",
	["CYCLE_MATERIAL_BW"]     = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_BW",
	["SELECT_ALL_MATERIALS"]  = "UNIVERSALAUTOLOAD_SELECT_ALL_MATERIALS",
	["CYCLE_CONTAINER_FW"]    = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW",
	["CYCLE_CONTAINER_BW"]    = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_BW",
	["SELECT_ALL_CONTAINERS"] = "UNIVERSALAUTOLOAD_SELECT_ALL_CONTAINERS",
	["TOGGLE_BELTS"]	      = "UNIVERSALAUTOLOAD_TOGGLE_BELTS",
	["TOGGLE_DOOR"]           = "UNIVERSALAUTOLOAD_TOGGLE_DOOR",
	["TOGGLE_CURTAIN"]	      = "UNIVERSALAUTOLOAD_TOGGLE_CURTAIN",
	["TOGGLE_DEBUG"]	      = "UNIVERSALAUTOLOAD_TOGGLE_DEBUG"
}

UniversalAutoload.WARNINGS = {
	[1] = "warning_UNIVERSALAUTOLOAD_CLEAR_UNLOADING_AREA",
	[2] = "warning_UNIVERSALAUTOLOAD_NO_OBJECTS_FOUND",
	[3] = "warning_UNIVERSALAUTOLOAD_UNABLE_TO_LOAD_OBJECT",
	[4] = "warning_UNIVERSALAUTOLOAD_NO_LOADING_UNLESS_STATIONARY"
}

UniversalAutoload.CONTAINERS = {
	[1] = "ALL",
	[2] = "EURO_PALLET",
	[3] = "BIGBAG_PALLET",
	[4] = "LIQUID_TANK",
	[5] = "BIGBAG",
	[6] = "BALE"
}

-- DEFINE DEFAULTS FOR CONTAINER TYPES
UniversalAutoload.ALL            = { sizeX = 1.250, sizeY = 0.850, sizeZ = 0.850 }
UniversalAutoload.EURO_PALLET    = { sizeX = 1.250, sizeY = 0.790, sizeZ = 0.850 }
UniversalAutoload.BIGBAG_PALLET  = { sizeX = 1.525, sizeY = 1.075, sizeZ = 1.200 }
UniversalAutoload.LIQUID_TANK    = { sizeX = 1.433, sizeY = 1.500, sizeZ = 1.415 }
UniversalAutoload.BIGBAG         = { sizeX = 1.050, sizeY = 1.666, sizeZ = 0.866, neverStack=true }
UniversalAutoload.BALE           = { isBale=true }

UniversalAutoload.VEHICLES = {}
UniversalAutoload.UNKNOWN_TYPES = {}

-- IMPORT VEHICLE CONFIGURATIONS
UniversalAutoload.VEHICLE_CONFIGURATIONS = {}

function UniversalAutoload.ImportUserConfigurations(userSettingsFile, overwriteExisting)

	if g_currentMission.isMultiplayer then
		print("Custom configurations are not supported in multiplayer")
		return
	end
	
	local N,M = 0,0
	if fileExists(userSettingsFile) then
		print("IMPORT user vehicle configurations")
		N = N + UniversalAutoload.ImportVehicleConfigurations(userSettingsFile, overwriteExisting)
		print("IMPORT user container configurations")
		M = M + UniversalAutoload.ImportContainerTypeConfigurations(userSettingsFile, overwriteExisting)
	else
		print("CREATING user settings file")
		local defaultSettingsFile = Utils.getFilename("config/UniversalAutoload.xml", UniversalAutoload.path)
		copyFile(defaultSettingsFile, userSettingsFile, false)
	end
	
	return N,M
end

function UniversalAutoload.ImportVehicleConfigurations(xmlFilename, overwriteExisting)

	local i = 0
	local xmlFile = XMLFile.load("configXml", xmlFilename, UniversalAutoload.xmlSchema)
	if xmlFile ~= 0 then
	
		local globalConfigKey = "universalAutoload.vehicleConfigurations"
		local debugAll = xmlFile:getValue(globalConfigKey.."#showDebug", false)
		
		while true do
			local configKey = string.format("universalAutoload.vehicleConfigurations.vehicleConfiguration(%d)", i)

			if not xmlFile:hasProperty(configKey) then
				break
			end

			local configFileName = xmlFile:getValue(configKey.."#configFileName")
			if UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] == nil then
				UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] = {}
			end
				
			local configGroup = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
			local selectedConfigs = xmlFile:getValue(configKey.."#selectedConfigs") or "ALL"
			if configGroup[selectedConfigs] == nil or overwriteExisting then
				configGroup[selectedConfigs] = {}
				configGroup[selectedConfigs].loadingArea = {}
				
				local config = configGroup[selectedConfigs]
				
					local j = 0
					while true do
						local loadAreaKey = string.format("%s.loadingArea(%d)", configKey, j)
						if not xmlFile:hasProperty(loadAreaKey) then
							break
						end
						config.loadingArea[j+1] = {}
						config.loadingArea[j+1].width  = xmlFile:getValue(loadAreaKey.."#width")
						config.loadingArea[j+1].length = xmlFile:getValue(loadAreaKey.."#length")
						config.loadingArea[j+1].height = xmlFile:getValue(loadAreaKey.."#height")
						config.loadingArea[j+1].baleHeight = xmlFile:getValue(loadAreaKey.."#baleHeight", nil)
						config.loadingArea[j+1].offset = xmlFile:getValue(loadAreaKey.."#offset", "0 0 0", true)
						config.loadingArea[j+1].noLoadingIfFolded = xmlFile:getValue(loadAreaKey.."#noLoadingIfFolded", false)
						config.loadingArea[j+1].noLoadingIfUnfolded = xmlFile:getValue(loadAreaKey.."#noLoadingIfUnfolded", false)
						j = j + 1
					end
					
				config.isBoxTrailer = xmlFile:getValue(configKey..".options#isBoxTrailer", false)
				config.isCurtainTrailer = xmlFile:getValue(configKey..".options#isCurtainTrailer", false)
				config.enableRearLoading = xmlFile:getValue(configKey..".options#enableRearLoading", false)
				config.enableSideLoading = xmlFile:getValue(configKey..".options#enableSideLoading", false)
				config.noLoadingIfFolded = xmlFile:getValue(configKey..".options#noLoadingIfFolded", false)
				config.noLoadingIfUnfolded = xmlFile:getValue(configKey..".options#noLoadingIfUnfolded", false)
				--config.disableAutoStrap = xmlFile:getValue(configKey..".options#disableAutoStrap", false)
				config.showDebug = xmlFile:getValue(configKey..".options#showDebug", debugAll)

				if not config.showDebug then
					print("  >> "..configFileName.." ("..selectedConfigs..")")
				else
					print("  >> "..configFileName.." ("..selectedConfigs..") DEBUG")
				end
			else
				print("  CONFIG ALREADY EXISTS: "..configFileName.." ("..selectedConfigs..")")
			end
			
			i = i + 1
		end

		xmlFile:delete()
	end
	return i
end

-- IMPORT CONTAINER TYPE DEFINITIONS
UniversalAutoload.LOADING_TYPE_CONFIGURATIONS = {}
function UniversalAutoload.ImportContainerTypeConfigurations(xmlFilename, overwriteExisting)

	local i = 0
	local xmlFile = XMLFile.load("configXml", xmlFilename, UniversalAutoload.xmlSchema)
	if xmlFile ~= 0 then

		while true do
			local configKey = string.format("universalAutoload.containerConfigurations.containerConfiguration(%d)", i)
			
			if not xmlFile:hasProperty(configKey) then
				break
			end

			local containerType = xmlFile:getValue(configKey.."#containerType", "ALL")
			if tableContainsValue(UniversalAutoload.CONTAINERS, containerType) then
			
				local default = UniversalAutoload[containerType] or {}

				local name = xmlFile:getValue(configKey.."#name")
				local config = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
				if config == nil or overwriteExisting then
					UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] = {}
					newType = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
					newType.name = name
					newType.type = containerType
					newType.containerIndex = UniversalAutoload.CONTAINERS_INDEX[containerType] or 1
					newType.sizeX = xmlFile:getValue(configKey.."#sizeX", default.sizeX or 1.5)
					newType.sizeY = xmlFile:getValue(configKey.."#sizeY", default.sizeY or 1.5)
					newType.sizeZ = xmlFile:getValue(configKey.."#sizeZ", default.sizeZ or 1.5)
					newType.isBale = xmlFile:getValue(configKey.."#isBale", default.isBale or false)
					newType.flipYZ = xmlFile:getValue(configKey.."#flipYZ", default.flipYZ or false)
					newType.neverStack = xmlFile:getValue(configKey.."#neverStack", default.neverStack or false)
					newType.neverRotate = xmlFile:getValue(configKey.."#neverRotate", default.neverRotate or false)
					newType.alwaysRotate = xmlFile:getValue(configKey.."#alwaysRotate", default.alwaysRotate or false)
					print(string.format("  >> %s %s [%.3f, %.3f, %.3f]", containerType, newType.name, newType.sizeX, newType.sizeY, newType.sizeZ ))
				end

			else
				print("  UNKNOWN CONTAINER TYPE: "..tostring(containerType))
			end

			i = i + 1
		end

		xmlFile:delete()
	end
	return i

end
--
function UniversalAutoload.importContainerTypeFromXml(xmlFilename, customEnvironment)

	if xmlFilename ~= nil and not string.find(xmlFilename, "multiPurchase") then	
		--print( "  >> " .. xmlFilename )
		local loadedVehicleXML = false
		local xmlFile = XMLFile.load("configXml", xmlFilename, Vehicle.xmlSchema)

		if xmlFile~=nil and xmlFile:hasProperty("vehicle.base") then
			loadedVehicleXML = true
			UniversalAutoload.importPalletTypeFromXml(xmlFile, customEnvironment)
		end
		xmlFile:delete()
		
		if not loadedVehicleXML then
			xmlFile = XMLFile.load("baleConfigXml", xmlFilename, BaleManager.baleXMLSchema)
			if xmlFile~=nil and xmlFile:hasProperty("bale") then
				UniversalAutoload.importBaleTypeFromXml(xmlFile, customEnvironment)
			end
			xmlFile:delete()
		end
		
	end
end
--
function UniversalAutoload.importPalletTypeFromXml(xmlFile, customEnvironment)
	
	local i3d_path = xmlFile:getValue("vehicle.base.filename")
	local i3d_name = UniversalAutoload.getObjectNameFromI3d(i3d_path)
	
	if i3d_name ~= nil then
		local name
		if customEnvironment == nil then
			name = i3d_name
		else
			name = customEnvironment..":"..i3d_name
		end
		
		if UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] == nil then
		
			local category = xmlFile:getValue("vehicle.storeData.category", "NONE")
			local width = xmlFile:getValue("vehicle.base.size#width", 1.5)
			local height = xmlFile:getValue("vehicle.base.size#height", 1.5)
			local length = xmlFile:getValue("vehicle.base.size#length", 1.5)
			
			local containerType
			if string.find(i3d_name, "liquidTank") or string.find(i3d_name, "IBC") then containerType = "LIQUID_TANK"
			elseif string.find(i3d_name, "bigBag") or string.find(i3d_name, "BigBag") then containerType = "BIGBAG"
			elseif string.find(i3d_name, "pallet") or string.find(i3d_name, "Pallet") then containerType = "EURO_PALLET"
			elseif category == "pallets" then containerType = "EURO_PALLET"
			elseif category == "bigbags" then containerType = "BIGBAG"
			elseif category == "bigbagPallets" then containerType = "BIGBAG_PALLET"
			else
				containerType = "ALL"
				print("  USING DEFAULT CONTAINER TYPE: "..name.." - "..category)
			end

			UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] = {}
			newType = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
			newType.name = name
			newType.type = containerType or "ALL"
			newType.containerIndex = UniversalAutoload.CONTAINERS_INDEX[containerType] or 1
			newType.sizeX = width
			newType.sizeY = height
			newType.sizeZ = length
			newType.isBale = false
			newType.flipYZ = false
			newType.neverStack = (containerType == "BIGBAG") or false
			newType.neverRotate = false
			newType.alwaysRotate = false
			newType.width = math.min(newType.sizeX, newType.sizeZ)
			newType.length = math.max(newType.sizeX, newType.sizeZ)
				
			print(string.format("  >> %s [%.3f, %.3f, %.3f] - %s", newType.name,
				newType.sizeX, newType.sizeY, newType.sizeZ, containerType ))
				
		end
	end
end
--
function UniversalAutoload.importBaleTypeFromXml(xmlFile, customEnvironment)
	
	local i3d_path = xmlFile:getValue("bale.filename")
	local i3d_name = UniversalAutoload.getObjectNameFromI3d(i3d_path)
	
	if i3d_name ~= nil then
		local name
		if customEnvironment == nil then
			name = i3d_name
		else
			name = customEnvironment..":"..i3d_name
		end
		
		if UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] == nil then
		
			local containerType = "BALE"
			local width = xmlFile:getValue("bale.size#width", 1.5)
			local height = xmlFile:getValue("bale.size#height", 1.5)
			local length = xmlFile:getValue("bale.size#length", 2.4)
			local diameter = xmlFile:getValue("bale.size#diameter", 1.8)
			local isRoundbale = xmlFile:getValue("bale.size#isRoundbale", "false")

			UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] = {}
			newType = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
			newType.name = name
			newType.type = containerType
			newType.containerIndex = UniversalAutoload.CONTAINERS_INDEX[containerType] or 1
			if isRoundbale then
				newType.sizeX = diameter
				newType.sizeY = width
				newType.sizeZ = diameter
			else
				newType.sizeX = width
				newType.sizeY = height
				newType.sizeZ = length
			end
			newType.isBale = true
			newType.flipYZ = isRoundbale
			newType.neverStack = false
			newType.neverRotate = false
			newType.alwaysRotate = false
			newType.width = math.min(newType.sizeX, newType.sizeZ)
			newType.length = math.max(newType.sizeX, newType.sizeZ)
				
			print(string.format("  >> %s [%.3f, %.3f, %.3f] - %s", newType.name,
				newType.sizeX, newType.sizeY, newType.sizeZ, containerType ))
				
		end
	end
end
--
function UniversalAutoload.detectOldConfigVersion()
	local userSettingsFile = Utils.getFilename(UniversalAutoload.userSettingsFile, getUserProfileAppPath())

	if fileExists(userSettingsFile) then

		local xmlFile = XMLFile.load("configXml", userSettingsFile, UniversalAutoload.xmlSchema)
		if xmlFile ~= 0 then
			local oldConfigKey = "universalAutoload.containerTypeConfigurations"
			if xmlFile:hasProperty(oldConfigKey) then
				print("========================================================================")
				print("** UNIVERSAL AUTOLOAD - LOCAL MOD SETTINGS FILE IS OUT OF DATE        **")
				print("** Please update container config key to:  <containerConfigurations>  **")
				print("========================================================================")
			end
			xmlFile:delete()
		end
	end
end
--
function UniversalAutoload.detectKeybindingConflicts()
	--DETECT 'T' KEYS CONFLICT
	if g_currentMission.missionDynamicInfo.isMultiplayer and not g_dedicatedServer then

		local chatKey = ""
		local containerKey = "KEY_t"
		local xmlFile = loadXMLFile('TempXML', g_gui.inputManager.settingsPath)	
		local actionBindingCounter = 0
		if xmlFile ~= 0 then
			while true do
				local key = string.format('inputBinding.actionBinding(%d)', actionBindingCounter)
				local actionString = getXMLString(xmlFile, key .. '#action')
				if actionString == nil then
					break
				end
				if actionString == 'CHAT' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput == "KEY_t" then
							print("  Using 'KEY_t' for 'CHAT'")
							chatKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				if actionString == 'UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput ~= nil then
							print("  Using '"..bindingInput.."' for 'CYCLE_CONTAINER'")
							containerKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				actionBindingCounter = actionBindingCounter + 1
			end
		end
		delete(xmlFile)
		
		if chatKey == containerKey then
			print("**CHAT KEY CONFLICT DETECTED** - Disabling CYCLE_CONTAINER for Multiplayer")
			print("(Please reassign 'CHAT' or 'CYCLE_CONTAINER' to a different key and RESTART the game)")
			UniversalAutoload.chatKeyConflict = true
		end
		
	end
end

function UniversalAutoload:consoleImportUserConfig(forceResetAll)
	local usage = "Usage: ualImportUserConfig [forceResetAll]"
	
	if g_currentMission:getIsServer() and not g_currentMission.missionDynamicInfo.isMultiplayer then

		local userSettingsFile = Utils.getFilename(UniversalAutoload.userSettingsFile, getUserProfileAppPath())
		local N, M = UniversalAutoload.ImportUserConfigurations(userSettingsFile, true)
		
		if N > 0 then
			if g_gui.currentGuiName == "ShopMenu" or g_gui.currentGuiName == "ShopConfigScreen" then
				return "Reload not supported while in shop!"
			end
			
			forceResetAll = Utils.stringToBoolean(forceResetAll)
			if forceResetAll then
				resetList = {}
				for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
					if vehicle ~= nil then
						table.insert(resetList, vehicle)
					end
				end
				UniversalAutoload.VEHICLES = {}
				for _, vehicle in pairs(resetList)  do
					print("RESETTING: " .. vehicle:getFullName())
					
					local xmlFile = Vehicle.getReloadXML(vehicle)
					local key = "vehicles.vehicle(0)"

					local function asyncCallbackFunction(_, newVehicle, vehicleLoadState, arguments)
						if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
							g_messageCenter:publish(MessageType.VEHICLE_RESET, vehicle, newVehicle)
							g_currentMission:removeVehicle(vehicle)
						else
							print("ERROR RESETTING: " .. vehicle:getFullName())
							if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_ERROR then
								print(" >> VEHICLE_LOAD_ERROR")
							end
							if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_DELAYED then
								print(" >> VEHICLE_LOAD_DELAYED")
							end
							if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_NO_SPACE then
								print(" >> There was no space available at the shop")
							end
							g_currentMission:removeVehicle(vehicle)
							g_currentMission:removeVehicle(newVehicle)
						end

						xmlFile:delete()
					end

					VehicleLoadingUtil.loadVehicleFromSavegameXML(xmlFile, key, true, true, nil, nil, asyncCallbackFunction, nil, {})
					--(xmlFile, key, resetVehicle, allowDelayed, xmlFilename, keepPosition, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
				end
			end
		end
	else
		print("***Reload only supported for single player games***")
	end
	return "UAL loacal settings were reloaded"
end

function UniversalAutoload:consoleAddPallets(palletType)
	local usage = "Usage: ualAddPallets [palletType]"
	
	local pallets = {}
	for _, fillType in pairs(g_fillTypeManager:getFillTypes()) do
		if fillType.palletFilename ~= nil then
			pallets[fillType.name] = fillType.palletFilename
		end
	end
		
	if palletType then
		palletType = string.upper(palletType or "")
		local xmlFilename = pallets[palletType]
		if xmlFilename == nil then
			return "Error: Invalid pallet type. Valid types are " .. table.concatKeys(pallets, " ")
		end
		
		pallets = {}
		pallets[palletType] = xmlFilename
	end
	
	if g_currentMission.controlledVehicle ~= nil then
	
		local vehicles = {}
		if g_currentMission.controlledVehicle.spec_universalAutoload ~= nil then
			table.insert(vehicles, g_currentMission.controlledVehicle.spec_universalAutoload)
		else
			if g_currentMission.controlledVehicle.getAttachedImplements ~= nil then
				local attachedImplements = g_currentMission.controlledVehicle:getAttachedImplements()
				for _, implement in pairs(attachedImplements) do
					if implement.object.spec_universalAutoload ~= nil then
						table.insert(vehicles, implement.object)
						break
					end
				end
			end
		end
		
		if next(vehicles) ~= nil then
			for _, vehicle in pairs(vehicles) do
				UniversalAutoload.setContainerTypeIndex(vehicle, 2)
				UniversalAutoload.createPallets(vehicle, pallets)
			end
		end
	
	end
	return "Begin adding pallets now.."
end

function UniversalAutoload:consoleCreateBoundingBox()
	local usage = "Usage: ualCreateBoundingBox"

	for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
		if vehicle ~= nil then
			print("CREATING BOUNDING BOX: " .. vehicle:getFullName())
			UniversalAutoload.createBoundingBox(vehicle)
		end
	end
end

function UniversalAutoloadManager:loadMap(name)

	if g_modIsLoaded["FS22_Seedpotato_Farm_Pack"] or g_modIsLoaded["FS22_SeedPotatoFarmBuildings"] then
		print("** Seedpotato Farm Pack is loaded **")
		table.insert(UniversalAutoload.CONTAINERS, "POTATOBOX")
		UniversalAutoload.POTATOBOX = { sizeX = 1.850, sizeY = 1.100, sizeZ = 1.200 }
	end

	UniversalAutoload.CONTAINERS_INDEX = {}
	for i, key in ipairs(UniversalAutoload.CONTAINERS) do
		UniversalAutoload.CONTAINERS_INDEX[key] = i
	end
	
	UniversalAutoload.MATERIALS = {}
	table.insert(UniversalAutoload.MATERIALS, "ALL" )
	UniversalAutoload.MATERIALS_FILLTYPE = {}
	table.insert( UniversalAutoload.MATERIALS_FILLTYPE, {["title"]= g_i18n:getText("universalAutoload_ALL")} )
	for index, fillType in ipairs(g_fillTypeManager.fillTypes) do
		if fillType.name ~= "UNKNOWN" then
			table.insert(UniversalAutoload.MATERIALS, fillType.name )
			table.insert(UniversalAutoload.MATERIALS_FILLTYPE, fillType )
		end
	end
	
	--print("  ALL MATERIALS:")
	UniversalAutoload.MATERIALS_INDEX = {}
	for i, key in ipairs(UniversalAutoload.MATERIALS) do
		-- print("  - "..i..": "..key.." = "..UniversalAutoload.MATERIALS_FILLTYPE[i].title)
		UniversalAutoload.MATERIALS_INDEX[key] = i
	end
	
	-- USER SETTINGS FIRST
	local userSettingsFile = Utils.getFilename(UniversalAutoload.userSettingsFile, getUserProfileAppPath())
	UniversalAutoload.ImportUserConfigurations(userSettingsFile)
	
	-- DEFAULT SETTINGS SECOND
	print("IMPORT supported vehicle configurations")
	local vehicleSettingsFile = Utils.getFilename("config/SupportedVehicles.xml", UniversalAutoload.path)
	UniversalAutoload.ImportVehicleConfigurations(vehicleSettingsFile)
	print("IMPORT supported container configurations")
	local ContainerTypeSettingsFile = Utils.getFilename("config/ContainerTypes.xml", UniversalAutoload.path)
	UniversalAutoload.ImportContainerTypeConfigurations(ContainerTypeSettingsFile)
	
	-- ADDITIONAL SETTINGS THIRD
	print("ADDITIONAL fill type containers")
    for index, fillType in ipairs(g_fillTypeManager.fillTypes) do
		if fillType.palletFilename then
			local customEnvironment = UniversalAutoload.getEnvironmentNameFromPath(fillType.palletFilename)
			UniversalAutoload.importContainerTypeFromXml(fillType.palletFilename, customEnvironment)
		end
    end
	for index, baleType in ipairs(g_baleManager.bales) do
		if baleType.isAvailable then
			local customEnvironment = UniversalAutoload.getEnvironmentNameFromPath(baleType.xmlFilename)
			UniversalAutoload.importContainerTypeFromXml(baleType.xmlFilename, customEnvironment)
		end
	end
	for _, storeItem in pairs(g_storeManager:getItems()) do
		if storeItem.isMod and
		   storeItem.categoryName == "BALES" or
		   storeItem.categoryName == "BIGBAGS" or
		   storeItem.categoryName == "PALLETS" or
		   storeItem.categoryName == "BIGBAGPALLETS"
		then
			UniversalAutoload.importContainerTypeFromXml(storeItem.xmlFilename, storeItem.customEnvironment)
		end	
	end
	
	UniversalAutoload.detectOldConfigVersion()
	UniversalAutoload.detectKeybindingConflicts()
	
	addConsoleCommand("ualAddPallets", "Fill current vehicle with specified pallets (experimental)", "consoleAddPallets", UniversalAutoload)
	addConsoleCommand("ualImportUserConfig", "Force a reload of configurations from local user settings file", "consoleImportUserConfig", UniversalAutoload)
	addConsoleCommand("ualCreateBoundingBox", "Create a bounding box around all loaded pallets (experimental)", "consoleCreateBoundingBox", UniversalAutoload)

end

function UniversalAutoloadManager:deleteMap()
end

function tableContainsValue(container, value)
	for k, v in pairs(container) do
		if v == value then
			return true
		end
	end
	return false
end
