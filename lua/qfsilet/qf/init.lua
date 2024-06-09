local fn = vim.fn
local api = vim.api
local cmd = vim.cmd

local Utils = require("qfsilet.utils")
local Plenary_path = require("plenary.path")
local Note = require("qfsilet.note")

local qf = {
	base_path = "",
	base_global_path = "",
	hash_note = "",
	save_mode = false,
}

local function set_current_list(cur_list, is_local, win_id)
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
			-- TODO: setting auto save?
			return
		end
	end
end

function qf.saveqf()
	Note.saveqf_list()
end

function qf.loadqf()
	Note.loadqf_list()
end

function qf.fzf_qf()
	require("fzf-lua").quickfix({
		prompt = "    ",
	})
end

local function is_vim_list_open()
	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)
		local location_list = Utils.isLocList()
		if vim.bo[buf].filetype == "qf" or location_list then
			return true
		end
	end
	return false
end

local function toggle_list(list_type, kill)
	if kill then
		return cmd([[q]])
	end

	local is_location_target = list_type == "location"
	local cmd_ = is_location_target and { "lclose", "lopen" } or { "cclose", "copen" }
	local is_open = is_vim_list_open()
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
	vim.cmd([[wincmd p]])
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
	local win_id = fn.win_getid()
	local is_loc = fn.getwininfo(win_id)[1].loclist == 1

	cur_list = Utils.getCurrentList({}, is_loc)

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
			local p = Plenary_path:new(fn.expand(tostring(note_fpath)))
			if p:exists() then
				p:rm()
			end
		end
		table.remove(cur_list, item)
	end

	if #cur_list ~= 0 then
		set_current_list(cur_list, false, win_id)
		if #cur_list == 0 then
			api.nvim_command(close_cmd)
		elseif item ~= 1 then
			Utils.feedkey("n", ("%dj"):format(item - 1))
			api.nvim_command(close_cmd)
		end

		vim.cmd(string.format("%scfirst", curqfidx))
		vim.schedule(function()
			vim.cmd("noau copen")
			vim.cmd("wincmd J")
		end)
	elseif #cur_list == 0 then
		fn.setqflist({})
		cmd.cclose()
	end
end

function qf.clear_qf_list()
	Utils.info("Item lists cleared", "QFSilet")

	fn.setqflist({})
	cmd.cclose()
end

function qf.clear_loc_list()
	Utils.info("Item lists cleared", "QFSilet")

	fn.setloclist(0, {})
	cmd.lclose()
end

local function filter_qfsilet_items(cur_list)
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

return qf
