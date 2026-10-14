repeat task.wait() until game:IsLoaded()
if shared.rpbrv then shared.rpbrv:Uninject() end

-- ⚠️ 본인의 깃허브 유저네임으로 변경하세요!
local GITHUB_USER = "YOUR_GITHUB_USERNAME"
local REPO_NAME = "rpbrv"
local BRANCH = "main"

local LOADER_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/downloader.lua", GITHUB_USER, REPO_NAME, BRANCH)
local RAW_BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/", GITHUB_USER, REPO_NAME)

local _initArgs = ...
if type(_initArgs) ~= "table" then _initArgs = {} end

if identifyexecutor then
	if table.find({'Wave', 'Seliware', 'Volt'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local args = _initArgs
if type(args) == "table" and args.Closet then
	getgenv().Closet = true
else
	if getgenv().Closet == nil then
		getgenv().Closet = false
	end
end

local rpbrv
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and rpbrv then
		rpbrv:CreateNotification('rpbrv', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end

local queue_on_teleport = queue_on_teleport or function() end
local clear_teleport_queue = clear_teleport_queue or clearteleportqueue or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

if identifyexecutor and table.find({'Madium', 'Medium'}, ({identifyexecutor()})[1]) then
	local realgca = getcustomasset or getsynasset
	if realgca then
		getgenv().getcustomasset = function(path, ...)
			local args = {...}
			local function try()
				if not isfile(path) then return nil end
				local ok, res = pcall(function() return realgca(path, table.unpack(args)) end)
				if ok and res and res ~= '' then return res end
				return nil
			end
			local res = try()
			if res then return res end
			for _ = 1, 60 do
				task.wait(0.05)
				res = try()
				if res then return res end
			end
			return 'rbxassetid://0'
		end
	end
end

local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))
local teleportService = cloneref(game:GetService('TeleportService'))

-- 디렉토리 자동 생성
if not isfolder('rpbrv') then makefolder('rpbrv') end
if not isfolder('rpbrv/profiles') then makefolder('rpbrv/profiles') end
if not isfolder('rpbrv/assets') then makefolder('rpbrv/assets') end
if not isfolder('rpbrv/games') then makefolder('rpbrv/games') end
if not isfolder('rpbrv/guis') then makefolder('rpbrv/guis') end

if not isfile('rpbrv/profiles/commit.txt') then
	writefile('rpbrv/profiles/commit.txt', BRANCH)
end

local function downloadFile(path, func)
	if not isfile(path) then
		local res
		local success = false
		for attempt = 1, 3 do
			local commit = readfile('rpbrv/profiles/commit.txt') or BRANCH
			local targetPath = path:gsub('rpbrv/', '')
			local suc, result = pcall(function()
				return game:HttpGet(RAW_BASE_URL .. commit .. '/' .. targetPath, true)
			end)
			if suc and result ~= '404: Not Found' then
				res = result
				success = true
				break
			end
			task.wait(1)
		end
		if not success then
			error('Failed to download ' .. path .. ' after 3 attempts')
		end
		if path:find('%.lua') then
			res = '-- [rpbrv module cache]\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function migrateProfiles()
	if isfile('rpbrv/profiles/migrated_placeid.txt') then return end

	local oldId = tostring(game.GameId)
	local newId = tostring(game.PlaceId)

	if oldId == newId then
		pcall(writefile, 'rpbrv/profiles/migrated_placeid.txt', 'done')
		return
	end

	local suffix = oldId .. '.txt'
	if isfolder('rpbrv/profiles') then
		for _, path in ipairs(listfiles('rpbrv/profiles')) do
			local name = path:gsub('\\', '/')
			if name:sub(-#suffix) == suffix then
				local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
				if not isfile(newPath) then
					pcall(function() writefile(newPath, readfile(path)) end)
				end
			end
		end
	end

	pcall(writefile, 'rpbrv/profiles/migrated_placeid.txt', 'done')
end

pcall(migrateProfiles)

local function finishLoading()
	rpbrv.Init = nil
	if not rpbrv.Load then
		warn('[rpbrv] rpbrv.Load is nil skipping load')
		return
	end
	rpbrv:Load()
	rpbrv:Clean(task.spawn(function()
		repeat
			pcall(rpbrv.Save, rpbrv)
			task.wait(10)
		until rpbrv.Loaded == nil
	end))

	local function buildTeleportScript()
		if shared.RpbrvIndependent then return nil end

		local closetArg = getgenv().Closet and '({Closet=true})' or '()'
		local teleportScript = 'shared.rpbrvreload = true\nloadstring(game:HttpGet("' .. LOADER_URL .. '", true), "loader")' .. closetArg

		if identifyexecutor and ({identifyexecutor()})[1] == 'Potassium' then
			teleportScript = 'task.wait(12)\n' .. teleportScript
		end
		if shared.RpbrvDeveloper then
			teleportScript = 'shared.RpbrvDeveloper = true\n' .. teleportScript
		end
		if shared.RpbrvCustomProfile then
			teleportScript = 'shared.RpbrvCustomProfile = "' .. shared.RpbrvCustomProfile .. '"\n' .. teleportScript
		end
		return teleportScript
	end

	local function queueTeleport()
		local teleportScript = buildTeleportScript()
		if not teleportScript then return end
		pcall(clear_teleport_queue)
		pcall(queue_on_teleport, teleportScript)
	end

	queueTeleport()

	rpbrv:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Failed then return end
		pcall(function() rpbrv:Save() end)
		queueTeleport()
	end))

	rpbrv:Clean(function()
		pcall(clear_teleport_queue)
	end)

	if not shared.rpbrvreload then
		if not rpbrv.Categories then return end
		if rpbrv.Categories.Main.Options['GUI bind indicator'].Enabled then
			rpbrv:CreateNotification('[rpbrv]', 'Successfully Loaded! Press ' .. table.concat(rpbrv.Keybind, ' + '):upper() .. ' to open GUI', 5)
		end
	end
end

if not isfile('rpbrv/profiles/gui.txt') then
	writefile('rpbrv/profiles/gui.txt', 'new')
end
local gui = readfile('rpbrv/profiles/gui.txt')

if not isfolder('rpbrv/assets/' .. gui) then
	makefolder('rpbrv/assets/' .. gui)
end

local guiSource = downloadFile('rpbrv/guis/' .. gui .. '.lua')
local guiFunc, guiErr = loadstring(guiSource, 'gui')
if not guiFunc then
	local errMsg = tostring(guiErr)
	local lineNum = errMsg:match(':(%d+):')
	local context = ''
	if lineNum then
		local n = tonumber(lineNum)
		local lines = guiSource:split('\n')
		local from = math.max(1, n - 2)
		local to   = math.min(#lines, n + 2)
		local parts = {}
		for i = from, to do
			local marker = i == n and '>>> ' or '    '
			table.insert(parts, marker .. i .. ': ' .. (lines[i] or ''))
		end
		context = '\n\nContext:\n' .. table.concat(parts, '\n')
	end
	error('[rpbrv] syntax error in ' .. gui .. '.lua' .. '\n' .. errMsg .. context)
end
rpbrv = guiFunc()
if not rpbrv then
	error('[rpbrv] GUI returned nil file may be corrupted.')
end
if not rpbrv.Load then
	if delfile then pcall(function() delfile('rpbrv/guis/' .. gui .. '.lua') end) then end
	error('[rpbrv] gui file corrupted (missing load).')
end
if not rpbrv.Init and not rpbrv.Load then
	error('[rpbrv] failed to initialize properly.')
end
shared.rpbrv = rpbrv
task.wait(0.1)

if getgenv().Closet then
	local LogService = cloneref(game:GetService('LogService'))
	local originals = {}
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == 'function' then
			local original = hookfunction(getgenv()[funcName], function() end)
			originals[funcName] = original
		end
	end
	hook('print')
	hook('warn')
	hook('error')
	hook('info')
	pcall(function() LogService:ClearOutput() end)
	local conn = LogService.MessageOut:Connect(function()
		LogService:ClearOutput()
	end)
	getgenv()._rpbrv_log_connection = conn
	getgenv()._rpbrv_originals = originals
end

if not shared.RpbrvIndependent then
	loadstring(downloadFile('rpbrv/games/universal.lua'), 'universal')()
	local gameFileId = (game.GameId == 2619619496) and (game.PlaceId == 6872265039 and 6872265039 or 6872274481) or (game.GameId == 10516888336 and 10516888336 or game.PlaceId)

	if isfile('rpbrv/games/' .. gameFileId .. '.lua') then
		local gameSrc = downloadFile('rpbrv/games/'..gameFileId..'.lua')
		local gameFunc, gameErr = loadstring(gameSrc, tostring(gameFileId))
		if not gameFunc then
			error('[rpbrv] syntax error in game script: ' .. tostring(gameErr))
		end
		gameFunc(...)
	else
		if not shared.RpbrvDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet(RAW_BASE_URL .. readfile('rpbrv/profiles/commit.txt') .. '/games/' .. gameFileId .. '.lua', true)
			end)
			if suc and res and res ~= '404: Not Found' then
				local path = 'rpbrv/games/' .. gameFileId .. '.lua'
				if not isfile(path) then
					writefile(path, '-- [rpbrv game cache]\n' .. res)
				end
				loadstring(readfile(path), tostring(gameFileId))(...)
			end
		end
	end
	finishLoading()
else
	rpbrv.Init = finishLoading
	return rpbrv
end
