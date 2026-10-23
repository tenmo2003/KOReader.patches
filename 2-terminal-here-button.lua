local FileManager = require("apps/filemanager/filemanager")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local function shellQuote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function getTerminal()
	local fm = FileManager.instance
	return fm and fm.terminal
end

local function terminalButton(dir)
	return {
		{
			text = _("Open terminal here"),
			callback = function()
				local fm = FileManager.instance
				UIManager:close(fm.file_dialog)
				UIManager:close(fm.plus_dialog)
				local terminal = fm.terminal
				terminal:onTerminalStart()
				if terminal.is_shell_open then
					terminal:transmit("cd " .. shellQuote(dir) .. "\n")
				end
			end,
		},
	}
end

local orig_getPlusDialogButtons = FileManager.getPlusDialogButtons
function FileManager:getPlusDialogButtons()
	local title, buttons = orig_getPlusDialogButtons(self)
	if not self.selected_files and getTerminal() then
		table.insert(buttons, terminalButton(self.file_chooser.path))
	end
	return title, buttons
end

FileManager:addFileDialogButtons("terminal_here_button", function(file, is_file)
	if not getTerminal() then
		return
	end
	return terminalButton(is_file and file:match("(.*)/") or file)
end)
