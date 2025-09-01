local fn = vim.fn
local api = vim.api
local cmd = vim.cmd

local Utils = require("qfsilet.utils")
local Plenary_path = require("plenary.path")
local Note = require("qfsilet.note")
local Config = require("qfsilet.config").current_configs
local Ui = require("qfsilet.ui")

local last_winid = 0

local qf = {
	base_path = "",
	base_global_path = "",
	hash_note = "",
	save_mode = false,
}

local set_current_list = function(cur_list, is_local, win_id)
	win_id = win_id or fn.win_getid()
	is_local = is_local or false

	local what = {
		idx = "$",
		items = cur_list,
		title = is_local and fn.getloclist(0, { title = 0 }).title or fn.getqflist({ title = 0 }),
	}

	if is_local then
		fn.setloclist(win_id, {}, "r", {
			nr = "$",
			items = what.items,
			title = what.title,
		})
		return
	end

	fn.setqflist({}, "r", what)
end

function qf.saveqf()
	Note.saveqf_list()
end
function qf.loadqf()
	Note.loadqf_list()
end

local is_vim_list_open = function()
	local curbuf = api.nvim_get_current_buf()
	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)
		if curbuf == buf then
			if Utils.is_loclist(win) then
				return true, "location"
			end
			if vim.bo[buf].filetype == "qf" then
				return true, "quickfix"
			end
		end
	end
	return false, ""
end
local toggle_list = function(list_type, kill)
	if kill then
		return cmd([[q]])
	end

	local is_location_target = list_type == "location"
	local cmd_ = is_location_target and { "lclose", Config.theme_list.quickfix.lopen }
		or { "cclose", Config.theme_list.quickfix.copen }
	local is_open, qf_or_loclist = is_vim_list_open()

	if is_open and (list_type == qf_or_loclist) then
		vim.fn.win_gotoid(last_winid)
		vim.cmd(cmd_[1])
		return
	end

	local list = is_location_target and fn.getloclist(0) or fn.getqflist()
	if vim.tbl_isempty(list) then
		local msg_prefix = (is_location_target and "Location" or "QuickFix")
		Utils.warn(msg_prefix .. " List is Empty.", "QF")

		if vim.bo[0].filetype == "qf" then
			cmd.wincmd("p")
		end
		return
	end

	-- local winnr = fn.winnr()
	last_winid = vim.fn.win_getid()
	vim.cmd(cmd_[2])

	-- if fn.winnr() ~= winnr then
	-- 	cmd.wincmd("p")
	-- end
	-- cmd.wincmd("p")
end

function qf.toggle_qf()
	toggle_list("quickfix")
end
function qf.toggle_loclist()
	toggle_list("location")
end
function qf.del_itemqf()
	local curqfidx = vim.fn.line(".")

	local cur_list = {}
	local close_cmd = "close"
	local open_cmd = Config.theme_list.quickfix.copen
	local win_id = fn.win_getid()
	local is_loc = Utils.is_loclist()
	cur_list = Utils.getCurrentList({}, is_loc)
	if is_loc then
		close_cmd = "lclose"
		open_cmd = Config.theme_list.quickfix.lopen
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
			local p = Plenary_path:new(fn.expand(tostring(note_fpath)))
			if p:exists() then
				p:rm()
			end
		end
		table.remove(cur_list, item)
	end

	if #cur_list ~= 0 then
		if is_loc then
			set_current_list(cur_list, true, win_id)
		else
			set_current_list(cur_list, false, win_id)
		end

		if #cur_list == 0 then
			api.nvim_command(close_cmd)
		elseif item ~= 1 then
			Utils.feedkey("n", ("%dj"):format(item - 1))
			api.nvim_command(close_cmd)
		end

		if is_loc then
			vim.cmd(string.format("%slfirst", curqfidx))
		else
			vim.cmd(string.format("%scfirst", curqfidx))
		end

		vim.schedule(function()
			vim.cmd(open_cmd)
		end)
	elseif #cur_list == 0 then
		if is_loc then
			fn.setloclist(0, {}, "r")
		else
			fn.setqflist({})
		end

		api.nvim_command(close_cmd)
	end
end

local clear_qf_list = function()
	Utils.info("✅ The item list has been cleared", "QF")
	fn.setqflist({})
	cmd.cclose()
end
local clear_loc_list = function()
	Utils.info("✅ The item list has been cleared", "LF")
	fn.setloclist(0, {}, "r")
	cmd.lclose()
end

function qf.clear_all_item_lists()
	if Utils.is_loclist() then
		clear_loc_list()
		return
	end

	clear_qf_list()
end

local filter_qfsilet_items = function(cur_list)
	local new_list = {}
	for _, item in ipairs(cur_list) do
		if item.text:match("qfsilet") then
			local note_fpath = item.text:sub(5)
			local p = Plenary_path:new(fn.expand(note_fpath))
			if p:exists() then
				p:rm()
			end
		end
	end

	return new_list
end

function qf.clear_notes()
	Utils.info("All notes cleared", "QFSilet")
	local new_list = filter_qfsilet_items(fn.getloclist(0))
	fn.setloclist(0, new_list)

	new_list = filter_qfsilet_items(fn.getqflist())
	fn.setqflist(new_list)
end

local add_item_to_qf = function(list_type)
	if vim.bo.filetype == "qf" then
		return Utils.warn("Operation is not allowed inside the quickfix window", "QF")
	end

	local is_location_target = list_type == "location"
	local cmd_ = is_location_target and { "lclose", Config.theme_list.quickfix.lopen, "loclist" }
		or { "cclose", Config.theme_list.quickfix.copen, "qflist" }

	local title = is_location_target and fn.getloclist(0, { title = 0 }).title or fn.getqflist({ title = 0 }).title
	if title and title:match("setqflist") or #title == 0 then
		title = "Add item into " .. (is_location_target and "lf" or "qf")
	end

	local items = {
		{
			bufnr = vim.api.nvim_get_current_buf(),
			lnum = vim.api.nvim_win_get_cursor(0)[1],
			text = Utils.strip_whitespace(vim.api.nvim_get_current_line()),
			line = vim.api.nvim_get_current_line(),
		},
	}

	if is_location_target then
		fn.setloclist(0, {}, "a", { items = items, title = title })
	else
		fn.setqflist({}, "a", { items = items, title = title })
	end

	Utils.info(string.format("✅ Add %s -> %s", cmd_[3], vim.api.nvim_get_current_line()), "QF-" .. cmd_[3])

	local is_open, _ = is_vim_list_open()
	if not is_open then
		vim.cmd(cmd_[2])
		cmd("wincmd p")
	end
end

function qf.add_item_qf()
	add_item_to_qf("quickfix")
end
function qf.add_item_loc()
	add_item_to_qf("location")
end

local rename_title = function(list_type, win_id)
	win_id = win_id or fn.win_getid() -- or 0
	local is_location_target = list_type == "location"
	local cmd_ = is_location_target and { "lclose", Config.theme_list.quickfix.lopen, "QF-loclist" }
		or { "cclose", Config.theme_list.quickfix.copen, "QF-qflist" }

	if Utils.is_loclist() then
		Utils.warn(
			"Sorry, this action is not supported.\nNo API available to edit the title.\nOnly supported for quickfix lists.",
			cmd_[3]
		)
		-- setloclist ga bisa di set title karena via API nya seperti itu?
		-- vim.fn.setloclist(0, {}, "r", {
		-- 	title = title,
		-- 	-- items = cur_list,
		-- })
		return
	end

	Ui.input(function(inputMsg)
		if inputMsg == "" then
			return
		end

		local title = inputMsg
		title = title:gsub("%s", "_")
		title = title:gsub("%.", "_")

		vim.fn.setqflist({}, "r", { title = title })
		vim.cmd(cmd_[2])
	end, "Rename " .. cmd_[3])
end

function qf.rename_title()
	if Utils.is_loclist() then
		rename_title("location")
		return
	end
	rename_title("quickfix")
end

local move_win_to = function(direction)
	if vim.bo.filetype ~= "qf" then
		return
	end

	local cmd_open
	local list_type

	if Utils.is_loclist() then
		cmd_open = direction == "above" and "aboveleft lopen" or "belowright lopen"
		Config.theme_list.quickfix.lopen = cmd_open
		list_type = "location"
	else
		cmd_open = direction == "above" and "aboveleft copen" or "belowright copen"
		Config.theme_list.quickfix.copen = cmd_open
		list_type = "quickfix"
	end

	toggle_list(list_type)
	vim.cmd(cmd_open)
end

function qf.move_qf_to_above()
	move_win_to("above")
end
function qf.move_qf_to_bottom()
	move_win_to("below")
end

return qf
