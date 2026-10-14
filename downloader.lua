--!strict
-- rpbrv downloader.lua for Luau

local _args = ...
if type(_args) ~= "table" then _args = {} end

-- ⚠️ 본인의 깃허브 유저네임으로 변경하세요!
local GITHUB_USER = "kEn840525"
local REPO_NAME = "rpbrv"

local RAW_BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/", GITHUB_USER, REPO_NAME)
local API_BASE_URL = string.format("https://api.github.com/repos/%s/%s", GITHUB_USER, REPO_NAME)

local isfile = isfile or function(file: string): boolean
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file: string) writefile(file, '') end

-- 로컬 캐시 워터마크 주석 (업데이트 시 자동 삭제 대상 식별용)
local CACHE_WATERMARK = '-- [rpbrv auto-cached file]\n'

local function downloadFile(path: string, func: ((string) -> any)?): any
	if not isfile(path) then
		local suc, res = pcall(function()
			local commit = isfile('rpbrv/profiles/commit.txt') and readfile('rpbrv/profiles/commit.txt') or 'main'
			local targetPath = select(1, path:gsub('rpbrv/', ''))
			return game:HttpGet(RAW_BASE_URL .. commit .. '/' .. targetPath, true)
		end)
		if not suc or res == '404: Not Found' then 
			error('[rpbrv] Failed to download file: ' .. tostring(res)) 
		end
		if path:find('%.lua$') then
			res = CACHE_WATERMARK .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path: string)
	if not isfolder(path) then return end
	for _, file in ipairs(listfiles(path)) do
		if file:find('loader') then continue end
		if isfile(file) then
			local content = readfile(file)
			if content and content:find(CACHE_WATERMARK, 1, true) then
				pcall(delfile, file)
			end
		end
	end
end

-- 기본 디렉토리 구조 자동 생성
for _, folder in ipairs({'rpbrv', 'rpbrv/games', 'rpbrv/profiles', 'rpbrv/assets', 'rpbrv/libraries', 'rpbrv/guis'}) do
	if not isfolder(folder) then makefolder(folder) end
end

if not isfile('rpbrv/profiles/commit.txt') then
	writefile('rpbrv/profiles/commit.txt', 'main')
end

local function downloadPremadeProfiles(commit: string)
	local httpService = cloneref and cloneref(game:GetService('HttpService')) or game:GetService('HttpService')
	if isfolder('rpbrv/profiles/premade') then
		for _, file in ipairs(listfiles('rpbrv/profiles/premade')) do
			pcall(function() if isfile(file) then delfile(file) end end)
		end
	else
		makefolder('rpbrv/profiles/premade')
	end

	local success, response = pcall(function()
		return game:HttpGet(API_BASE_URL .. '/contents/profiles/premade?ref=' .. commit)
	end)

	if success and response then
		local ok, files = pcall(function() return httpService:JSONDecode(response) end)
		if ok and type(files) == 'table' then
			for _, file in ipairs(files) do
				if file.name and file.name:find('%.txt$') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = game.PlaceId
					local filePath = 'rpbrv/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt'
					local ds, dc = pcall(function() return game:HttpGet(file.download_url, true) end)
					if ds and dc and dc ~= '404: Not Found' then 
						writefile(filePath, dc) 
					end
				end
			end
		end
	end
end

if not shared.RpbrvDeveloper then
	local commit = isfile('rpbrv/profiles/commit.txt') and readfile('rpbrv/profiles/commit.txt') or ''
	local latest = isfile('rpbrv/profiles/latest.txt') and readfile('rpbrv/profiles/latest.txt') or ''
	
	if #commit ~= 40 then
		local ok, res = pcall(function()
			return game:HttpGet(API_BASE_URL .. '/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha"%s*:%s*"([a-f0-9]+)"')
			if h and #h == 40 then commit = h end
		end
		if #commit ~= 40 then commit = 'main' end
		latest = commit
		pcall(writefile, 'rpbrv/profiles/latest.txt', latest)
	elseif #latest == 40 and latest ~= commit then
		commit = latest
	end

	task.spawn(function()
		local ok, res = pcall(function()
			return game:HttpGet(API_BASE_URL .. '/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha"%s*:%s*"([a-f0-9]+)"')
			if h and #h == 40 then
				pcall(writefile, 'rpbrv/profiles/latest.txt', h)
			end
		end
	end)

	if commit ~= 'main' and (isfile('rpbrv/profiles/commit.txt') and readfile('rpbrv/profiles/commit.txt') or '') ~= commit then
		wipeFolder('rpbrv')
		wipeFolder('rpbrv/games')
		wipeFolder('rpbrv/guis')
		pcall(function() if isfile('rpbrv/guis/new.lua') then delfile('rpbrv/guis/new.lua') end end)
		wipeFolder('rpbrv/libraries')
		if isfolder('rpbrv/profiles/premade') then
			for _, file in ipairs(listfiles('rpbrv/profiles/premade')) do
				pcall(function() if isfile(file) then delfile(file) end end)
			end
		end
	end

	local oldCommit = isfile('rpbrv/profiles/commit.txt') and readfile('rpbrv/profiles/commit.txt') or ''
	writefile('rpbrv/profiles/commit.txt', commit)
	
	local needPremade = (oldCommit ~= commit)
	if not needPremade then
		needPremade = true
		if isfolder('rpbrv/profiles/premade') then
			for _ in ipairs(listfiles('rpbrv/profiles/premade')) do
				needPremade = false
				break
			end
		end
	end

	if needPremade then
		pcall(downloadPremadeProfiles, commit)
	end
end

local mainSource = downloadFile('rpbrv/main.lua')
local mainFunc, mainErr = loadstring(mainSource, 'main')

if not mainFunc then
	error('[rpbrv] Failed to load main.lua: ' .. tostring(mainErr))
end

return mainFunc({
	Closet = _args.Closet,
})
