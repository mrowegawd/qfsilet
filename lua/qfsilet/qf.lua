local fn, fmt, api, cmd = vim.fn, string.format, vim.api, vim.cmd

local Util = require("qfsilet.utils")
local Visual = require("qfsilet.visual")
local plenary_path = require("plenary.path")
local Note = require("qfsilet.note")
-- local Ui = require("qfsilet.ui")
-- local Config = require("qfsilet.config").current_configs

local qf = {}

qf.base_path = ""
qf.base_global_path = ""
qf.hash_note = ""
qf.save_mode = false

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

-- Makes the quickfix and local list prettier. Borrowed from nvim-bqf.
function _G.qftf(info)
	local items
	local ret = {}
	if info.quickfix == 1 then
		items = fn.getqflist({ id = info.id, items = 0 }).items
	else
		items = fn.getloclist(info.winid, { id = info.id, items = 0 }).items
	end
	local limit = 40
	local fname_fmt1, fname_fmt2 = "%-" .. limit .. "s", "…%." .. (limit - 1) .. "s"
	local valid_fmt = "%s │%5d:%-3d│%s %s"
	for i = info.start_idx, info.end_idx do
		local e = items[i]
		local fname = ""
		local str
		if e.valid == 1 then
			if e.bufnr > 0 then
				fname = fn.bufname(e.bufnr)
				if fname == "" then
					fname = "[No Name]"
				else
					fname = fname:gsub("^" .. vim.env.HOME, "~")
				end
				if #fname <= limit then
					fname = fname_fmt1:format(fname)
				else
					fname = fname_fmt2:format(fname:sub(1 - limit))
				end
			end
			local lnum = e.lnum > 99999 and -1 or e.lnum
			local col = e.col > 999 and -1 or e.col
			local qtype = e.type == "" and "" or " " .. e.type:sub(1, 1):upper()
			str = valid_fmt:format(fname, lnum, col, qtype, e.text)
		else
			str = e.text
		end
		table.insert(ret, str)
	end
	return ret
end
function qf.addjustWindowHWQf(maxheight, minheight)
	maxheight = maxheight or 7
	minheight = minheight or 4
	local l = 1
	local n_lines = 0
	local w_width = fn.winwidth(api.nvim_get_current_win())

	for i = l, fn.line("$") do
		local l_len = fn.strlen(fn.getline(l)) + 0.0
		local line_width = l_len / w_width
		n_lines = n_lines + fn.float2nr(fn.ceil(line_width))
		i = i + 1
	end

	local getheight = fn.max({ fn.min({ n_lines, maxheight }), minheight })
	if getheight > maxheight then
		cmd(fmt("%swincmd _", tostring(maxheight)))
	else
		cmd(fmt("%swincmd _", getheight))
	end
end

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

local function __set_current_list(cur_list, is_local, win_id)
	win_id = fn.win_getid() or win_id
	is_local = false or is_local

	if is_local then
		fn.setloclist(win_id, cur_list)
	else
		local what = {
			idx = "$",
			items = cur_list,
			title = fn.getqflist({ title = 0 }),
		}

		fn.setqflist({}, "r", what)

		if qf.save_mode then
			-- TODO: settings auto save?
			print("")
		end
	end
end
local function __note_insertqf_allowed()
	local ft = vim.bo[0].filetype
	local is_loclist = Util.is_loc_list()
	local is_floatwin = api.nvim_win_get_config(0).relative ~= ""

	if is_loclist or ft == "qf" or is_floatwin then
		return true
	end
	return false
end
local function __insert_list(items, is_local)
	local cur_list = Util.get_current_lists(items, is_local)

	__set_current_list(cur_list, is_local)

	if Visual.extmarks.set_extmarks then
		Visual.insert_extmarks(items, is_local)
	end
	if Visual.extmarks.set_signs then
		Visual.insert_signs(items, is_local)
	end

	Visual.setup_buf_autocmds(is_local)
end
local function __insert_note_to_list(is_note, location, dir_hash, is_local)
	local qf_note = ""

	if not is_note then
		qf_note = api.nvim_get_current_line()
	else
		qf_note = " " .. dir_hash
	end

	local item = {
		bufnr = fn.bufnr(),
		lnum = location[1],
		col = location[2] + 1,
		text = qf_note,
		type = Visual.extmarks.unique_id,
	}
	__insert_list({ item }, is_local)
end

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

function qf.saveqf_local()
	Note.saveqflist_local()
end
function qf.saveqf_global()
	Note.saveqflist_global()
end

function qf.loadqf_local()
	Note.loadqflist_local()
end
function qf.loadqf_global()
	Note.loadqflist_global()
end

function qf.add_todo()
	Note.todo_local()
end
function qf.add_todo_global()
	Note.todo_global()
end

function qf.add_todo_capture_link()
	Note.todo_with_capture_link()
end

function qf.goto_link_capture()
	Note.todo_goto_capture_link()
end

function qf.add_item_toqf()
	if __note_insertqf_allowed() then
		return Util.warn("Cannot insert...\n(Do not do this inside qf)", "QFSilet")
	end

	local location = api.nvim_win_get_cursor(0)
	__insert_note_to_list(false, location, false)
end

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

local function __is_vim_list_open()
	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)
		local location_list = Util.is_loc_list()
		if vim.bo[buf].filetype == "qf" or location_list then
			return true
		end
	end
	return false
end
local function __toggle_list(list_type, kill)
	if kill then
		return cmd([[q]])
	end

	local is_location_target = list_type == "location"
	local cmd_ = is_location_target and { "lclose", "lopen" } or { "cclose", "copen" }
	local is_open = __is_vim_list_open()
	if is_open then
		return cmd[cmd_[1]]()
	end
	local list = is_location_target and fn.getloclist(0) or fn.getqflist()
	if vim.tbl_isempty(list) then
		local msg_prefix = (is_location_target and "Location" or "QuickFix")
		return vim.notify(msg_prefix .. " List is Empty.", vim.log.levels.WARN)
	end

	local winnr = fn.winnr()
	cmd[cmd_[2]]()
	if fn.winnr() ~= winnr then
		cmd.wincmd("p")
	end
end

function qf.toggle_qf()
	__toggle_list("quickfix")
end
function qf.toggle_loclist()
	__toggle_list("location")
end

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

function qf.del_itemqf()
	local cur_list = {}
	local close_cmd = "close"
	local win_id = fn.win_getid()
	local is_loc = fn.getwininfo(win_id)[1].loclist == 1

	cur_list = Util.get_current_lists({}, is_loc)

	if is_loc then
		close_cmd = "lclose"
	end

	local count = vim.v.count
	if count == 0 then
		count = 1
	end
	if count > #cur_list then
		count = #cur_list
	end

	local item = api.nvim_win_get_cursor(0)[1]
	for _ = item, item + count - 1 do
		-- Delete note path nya juga
		if cur_list[item].text:match("qfsilet") then
			local item_text = cur_list[item].text
			local note_fpath = item_text:sub(5)
			local p = plenary_path:new(fn.expand(tostring(note_fpath)))
			if p:exists() then
				p:rm()
			end
		end
		table.remove(cur_list, item)
	end

	__set_current_list(cur_list, false, win_id)

	if #cur_list == 0 then
		api.nvim_command(close_cmd)
	elseif item ~= 1 then
		Util.feedkey("n", ("%dj"):format(item - 1))
	end

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end

--  ╭──────────────────────────────────────────────────────────╮
--  │ >>>                                                      │
--  ╰──────────────────────────────────────────────────────────╯

function qf.clear_qf_list()
	Util.info("Item lists cleared", "QFSilet")

	fn.setqflist({})
	cmd.cclose()

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end
function qf.clear_loc_list()
	Util.info("Item lists cleared", "QFSilet")

	fn.setloclist(0, {})
	cmd.lclose()

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end

local function __filter_qfsilet_items(cur_list)
	local new_list = {}
	for _, item in ipairs(cur_list) do
		if item.type ~= Visual.extmarks.unique_id then
			table.insert(new_list, item)
		else
			-- Delete note item
			if item.text:match("qfsilet") then
				local note_fpath = item.text:sub(5)
				local p = plenary_path:new(fn.expand(note_fpath))
				if p:exists() then
					p:rm()
				end
			end
		end
	end

	return new_list
end
function qf.clear_notes()
	Util.info("All notes cleared", "QFSilet")
	local new_list = __filter_qfsilet_items(fn.getloclist(0))
	fn.setloclist(0, new_list)

	new_list = __filter_qfsilet_items(fn.getqflist())
	fn.setqflist(new_list)

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end

return qf
