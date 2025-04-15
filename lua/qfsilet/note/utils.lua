local Utils = require("qfsilet.utils")
local Ui = require("qfsilet.ui")

local fn = vim.fn
local fmt = string.format
local api = vim.api
local cmd = vim.cmd

local M = {}

local function format_title_qf(base_path, title)
	local qf_title = fn.getqflist({ title = 0 }).title

	local fmt_str_title = function(prefix, str_title)
		prefix = #prefix > 0 and "_" .. prefix .. "-" or "-"
		prefix = str_title .. prefix
		return prefix
	end

	local prefix = ""
	if qf_title:match("%[FzfLua%]%sfiles:%s") then
		prefix = qf_title:gsub("%[FzfLua%]%sfiles:%s", "")
		prefix = fmt_str_title(prefix, "fzflua_file")
	end

	if qf_title:match("%[FzfLua%]%slive_grep_glob:%s") then
		prefix = qf_title:gsub("%[FzfLua%]%slive_grep_glob:%s", "")
		prefix = fmt_str_title(prefix, "fzflua_grep")
	end

	if qf_title:match("%[FzfLua%]%sblines:%s") then
		prefix = qf_title:gsub("%[FzfLua%]%sblines:%s", "")
		prefix = fmt_str_title(prefix, "fzflua_blines")
	end

	if qf_title:match("Fzf_diffview") then
		prefix = qf_title:gsub("Fzf_diffview", "")
		prefix = fmt_str_title(prefix, "fzf_diffview")
	end

	-- TODO: untuk prefix Octo, sepertinya format title dari plugin Octo tidak ada hanya tanda kurung '()'
	-- ini membuat susah untuk di buat format
	-- if qf_title:match("%s%(%)") then
	-- 	local qf_list = vim.fn.getqflist({ winid = 0, items = 0 })
	-- 	print(vim.inspect(qf_list.items))
	-- 	-- prefix = qf_title:gsub("%[FzfLua%]%sfiles:%s", "")
	-- 	-- prefix = prefix .. "_"
	-- end

	local fname = prefix .. title .. ".json"
	local fname_path = base_path .. "/" .. fname
	return fname_path, fname
end

function M.save_list_to_file(base_path, tbl, title)
	local fname_path, fname = format_title_qf(base_path, title)
	local success_msg = "Success saving"

	if Utils.isFile(fname_path) then
		Ui.input(function(input)
			if input ~= nil and input == "y" or #input < 1 then
				Utils.writeToFile(tbl, fname_path)
			else
				success_msg = "Cancel save"
			end
		end, fmt("File %s exists, rewrite it? [y/n]", title))
	else
		Utils.writeToFile(tbl, fname_path)
	end

	Utils.info(fmt("%s file '%s'", success_msg, fname))
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

local function is_file_in_buffers(filename)
	local buffers = vim.api.nvim_list_bufs()

	for _, buf in ipairs(buffers) do
		local bufname = vim.api.nvim_buf_get_name(buf)
		if bufname == filename then
			return buf
		end
	end

	return nil
end

function M.delete_buffer_by_name(filename)
	local buf = is_file_in_buffers(filename)
	if buf then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

return M
