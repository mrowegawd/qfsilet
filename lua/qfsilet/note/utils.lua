local Utils = require("qfsilet.utils")
local Ui = require("qfsilet.ui")

local fn = vim.fn
local fmt = string.format
local api = vim.api
local cmd = vim.cmd

local M = {}

function M.save_list_to_file(base_path, tbl, title, is_notify)
	title = title or fn.getqflist({ title = 0 })

	local fname_path = base_path .. "/" .. title .. ".json"
	local success_msg = "Success saving"

	if is_notify then
		if Utils.isFile(fname_path) then
			Ui.input(function(input)
				if input ~= nil and input == "y" or #input < 1 then
					Utils.writeToFile(tbl, fname_path)
				else
					success_msg = "Cancel save"
				end

				Utils.info(fmt("%s file %s.json", success_msg, title))
			end, fmt("File %s exists, rewrite it? [y/n]", title))
		else
			Utils.writeToFile(tbl, fname_path)
		end
	else
		Utils.writeToFile(tbl, fname_path)
	end
end

function M.get_current_list(items, isGlobal)
	local cur_list

	if isGlobal then
		cur_list = fn.getloclist(0)
	else
		cur_list = fn.getqflist()
	end

	if items ~= nil and #items > 0 then
		cur_list = vim.list_extend(cur_list, items)
	end

	return cur_list
end

function M.capturelink()
	return string.format(
		"[[file:%s::%s]]",
		Utils.current_file_path(),
		api.nvim_win_get_cursor(0)[1]
		-- api.nvim_win_get_cursor(0)[2]
	)
end

function M.gotolink()
	local str_file = fn.expand("<cWORD>")

	if not str_file:match("file:") then
		return
	end

	-- remove the bracket [[ ... ]]
	local fname = fn.split(str_file:match("file:(.*):"), ":")

	local sel_str = str_file:match("file:(.*).*")
	local tbl_col = fn.split(sel_str:match(":[0-9]+"), ":")
	local col = tonumber(tbl_col[1])

	cmd("e " .. fname[1])
	api.nvim_win_set_cursor(0, { col, 0 })
	cmd("silent! :e")
end

return M
