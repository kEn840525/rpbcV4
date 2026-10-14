--!strict
-- rpbrv reinstall script for Luau

local commit: string?
pcall(function()
	commit = readfile('rpbrv/profiles/commit.txt')
end)

local function wipe(path: string)
	if isfolder(path) then
		local files = listfiles(path)
		for _, item in ipairs(files) do
			wipe(item)
		end
		pcall(delfolder, path)
	elseif isfile(path) then
		pcall(delfile, path)
	end
end

if isfolder('rpbrv') then
	wipe('rpbrv')
end

pcall(function()
	game:GetService('StarterGui'):SetCore('SendNotification', {
		Title = 'rpbrv',
		Text = 'Deleted rpbrv cache & settings. Reinjecting...',
		Duration = 4
	})
end)

task.wait(0.67)

local targetCommit: string = commit or 'main'
local loaderUrl: string = string.format('https://raw.githubusercontent.com/kEn840525/rpbrv/%s/main.lua', targetCommit)

local suc, res = pcall(function()
	return game:HttpGet(loaderUrl, true)
end)

if suc and res and res ~= '' then
	local func = loadstring(res, 'main')
	if func then
		func()
	end
else
	warn('[rpbrv] Failed to reinject from: ' .. loaderUrl)
end
