local Archiver = require("ffi/archiver")
local FileManager = require("apps/filemanager/filemanager")
local InfoMessage = require("ui/widget/infomessage")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("gettext")
local T = ffiUtil.template

local pending_purge = {}

local function uniqueDir(base)
	local dir, n = base, 1
	while lfs.attributes(dir, "mode") or pending_purge[dir] do
		n = n + 1
		dir = base .. " (" .. n .. ")"
	end
	return dir
end

local function unzip(file, to_folder)
	local fm = FileManager.instance
	if fm and fm.file_dialog then
		UIManager:close(fm.file_dialog)
	end
	local function done(text, timeout)
		if fm then
			fm:onRefresh()
		end
		UIManager:show(InfoMessage:new({ text = text, timeout = timeout }))
	end

	local dir
	if to_folder then
		dir = uniqueDir((file:gsub("%.[zZ][iI][pP]$", "")))
		local ok, err = lfs.mkdir(dir)
		if not ok then
			return done(T(_("Unzip failed: %1"), tostring(err)))
		end
	else
		dir = file:match("(.*)/")
	end
	local function cleanup()
		if to_folder and lfs.attributes(dir, "mode") then
			ffiUtil.purgeDir(dir)
		end
	end

	-- A plain string would get Trapper's bottom-left TrapWidget; InfoMessage is centered.
	local progress = InfoMessage:new({ text = _("Unzipping…\n\nTap to cancel.") })
	UIManager:show(progress)
	UIManager:forceRePaint()
	local completed, result = Trapper:dismissableRunInSubprocess(function()
		local arc = Archiver.Reader:new()
		if not arc:open(file) then
			return tostring(arc.err)
		end
		for entry in arc:iterate() do
			if entry.mode == "file" and not arc:extractToPath(entry.path, dir .. "/" .. entry.path) then
				return tostring(arc.err)
			end
		end
		if arc.err then
			return arc.err
		end
		-- Trapper returns nil for empty output, so success needs a non-empty marker.
		return "ok"
	end, progress, true)
	-- Trapper only closes trap widgets it created itself.
	UIManager:close(progress)

	if not completed then
		cleanup()
		if to_folder then
			-- The killed subprocess may still flush a last write after the first purge.
			pending_purge[dir] = true
			UIManager:scheduleIn(2, function()
				cleanup()
				pending_purge[dir] = nil
			end)
		end
		done(_("Unzip cancelled."), 2)
	elseif result == "ok" then
		done(_("Unzipped."), 2)
	else
		cleanup()
		done(T(_("Unzip failed: %1"), result or _("unknown error")))
	end
end

FileManager:addFileDialogButtons("unzip_button", function(file, is_file)
	if not (is_file and util.getFileNameSuffix(file):lower() == "zip") then
		return
	end
	return {
		{
			text = _("Unzip here"),
			callback = function()
				Trapper:wrap(function()
					unzip(file, false)
				end)
			end,
		},
		{
			text = _("Unzip to folder"),
			callback = function()
				Trapper:wrap(function()
					unzip(file, true)
				end)
			end,
		},
	}
end)
