local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

FileManager:addFileDialogButtons("unzip_button", function(file, is_file)
	if not (is_file and util.getFileNameSuffix(file):lower() == "zip") then
		return
	end
	return {
		{
			text = _("Unzip here"),
			callback = function()
				local fm = FileManager.instance
				if fm and fm.file_dialog then
					UIManager:close(fm.file_dialog)
				end
				local dir = file:match("(.*)/")
				local ok, err = Device:unpackArchive(file, dir)
				if ok then
					if fm then
						fm:onRefresh()
					end
					UIManager:show(InfoMessage:new({ text = _("Unzipped."), timeout = 2 }))
				else
					UIManager:show(InfoMessage:new({ text = T(_("Unzip failed: %1"), tostring(err)) }))
				end
			end,
		},
	}
end)
