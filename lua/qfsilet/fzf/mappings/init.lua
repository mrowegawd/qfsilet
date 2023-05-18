local fn = vim.fn

local Path = require("qfsilet.path")
local Util = require("qfsilet.utils")
local Visual = require("qfsilet.visual")

local M = {}

local nbsp = "\xe2\x80\x82" -- "\u{2002}"

local function __lastIndexOf(haystack, needle)
	local i = haystack:match(".*" .. needle .. "()")
	if i == nil then
		return nil
	else
		return i - 1
	end
end

local function __stripBeforeLastOccurrenceOf(str, sep)
	local idx = __lastIndexOf(str, sep) or 0
	return str:sub(idx + 1), idx
end

local function __strip_ansi_coloring(str)
	if not str then
		return str
	end

	-- remove escape sequences of the following formats:
	-- 1. ^[[34m
	-- 2. ^[[0;34m
	-- 3. ^[[m
	return str:gsub("%[[%d;]-m", "")
end

local function __strip_str(selected)
	local pth = __strip_ansi_coloring(selected)
	if pth == nil then
		return
	end
	return __stripBeforeLastOccurrenceOf(pth, nbsp)
end

local function __merge_qf(selected, opts, base_path)
	local _tbl = {}

	if type(selected) == "table" then
		for _, sel in pairs(selected) do
			local pth = __strip_str(sel)
			local file_path = base_path .. "/" .. pth .. ".json"

			local file_read = Util.get_file_read(file_path)
			local json_tbl = fn.json_decode(file_read)
			if json_tbl ~= nil then
				if #json_tbl.qf.items > 0 then
					for _, tbl_val in pairs(json_tbl.qf.items) do
						table.insert(_tbl, tbl_val)
					end
				end
			end
		end
	else
		Util.warn("Not implemented yet, abort it", "QFSilet")
		return
	end

	local action = " " -- (a) append, (r) replace, " "
	local tryidx = "$"

	local what = {
		idx = tryidx,
		items = Util.rm_duplicates_tbl(_tbl),
		title = opts.prefix_title .. ":Merged",
	}

	fn.setqflist({}, action, what)
	vim.cmd("copen")

	Util.info("Import successful (merged)", "QFSilet")

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end

local function __edit_qf(selected, base_path)
	local pth = __strip_str(selected)
	if pth == nil then
		return
	end

	local file_path = base_path .. "/" .. pth .. ".json"

	local file_read = Util.get_file_read(file_path)
	local _tbl = fn.json_decode(file_read)

	if _tbl == nil then
		return
	end

	---@diagnostic disable-next-line: redefined-local
	local _tbl, title = Util.clean_up_items(_tbl)

	if #_tbl.qf.items == 0 then
		return
	end

	Util.write_to_file(_tbl, Path.defaults.base_path .. "/" .. title .. ".json")

	fn.setqflist({}, " ", _tbl.qf)
	vim.cmd("copen")

	Util.info("Import successful", "QFSilet")

	if Visual.extmarks.set_extmarks then
		Visual.update_extmarks()
	end
	if Visual.extmarks.set_signs then
		Visual.update_signs()
	end
end

function M.edit_or_merge_qf(opts, base_path)
	return {
		["default"] = function(selected, _)
			if #selected > 1 then
				__merge_qf(selected, opts, base_path)
			else
				__edit_qf(selected[1], base_path)
			end
		end,
		["ctrl-q"] = function(selected, _)
			if #selected > 1 then
				__merge_qf(selected, opts, base_path)
			else
				__edit_qf(selected[1], base_path)
			end
		end,
	}
end

function M.delete_item(base_path)
	return {
		["ctrl-x"] = function(selected, _)
			local pth = __strip_str(selected[1])
			if pth == nil then
				return
			end

			local file_path = base_path .. "/" .. pth .. ".json"

			if Util.is_file(file_path) then
				local cmd = "!rm"
				vim.api.nvim_exec2(cmd .. " " .. file_path, { output = true })
				vim.cmd("lua require'fzf-lua'.resume()")
			end
		end,
	}
end

return M
