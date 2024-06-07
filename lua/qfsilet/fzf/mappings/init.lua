local fn = vim.fn

local Constant = require("qfsilet.constant")
local Utils = require("qfsilet.utils")
local Visual = require("qfsilet.visual")

local M = {}

local nbsp = "\xe2\x80\x82" -- Non-breaking space unicode character "\u{2002}"

local function lastIndexOf(haystack, needle)
	local i = haystack:match(".*" .. needle .. "()")
	if i == nil then
		return nil
	else
		return i - 1
	end
end

local function stripBeforeLastOccurrenceOf(str, sep)
	local idx = lastIndexOf(str, sep) or 0
	return str:sub(idx + 1), idx
end

local function stripAnsiColoring(str)
	if not str then
		return str
	end
	-- Remove escape sequences of the following formats:
	-- 1. ^[[34m
	-- 2. ^[[0;34m
	-- 3. ^[[m
	return str:gsub("%[[%d;]-m", "")
end

local function stripString(selected)
	local pth = stripAnsiColoring(selected)
	if pth == nil then
		return
	end
	return stripBeforeLastOccurrenceOf(pth, nbsp)
end

local function mergeQuickFix(selected, opts, basePath)
	local tbl = {}

	if type(selected) == "table" then
		for _, sel in pairs(selected) do
			local pth = stripString(sel)
			local filePath = basePath .. "/" .. pth .. ".json"

			local fileRead = Utils.getFileRead(filePath)
			local jsonTbl = fn.json_decode(fileRead)
			if jsonTbl ~= nil then
				if #jsonTbl.qf.items > 0 then
					for _, tblVal in pairs(jsonTbl.qf.items) do
						table.insert(tbl, tblVal)
					end
				end
			end
		end
	else
		Utils.warn("Not implemented yet, abort it", "QFSilet")
		return
	end

	local action = " " -- (a) append, (r) replace, " "
	local tryIdx = "$"

	local what = {
		idx = tryIdx,
		items = Utils.removeDuplicates(tbl),
		title = opts.prefixTitle .. ":Merged",
	}

	fn.setqflist({}, action, what)
	vim.cmd("copen")

	Utils.info("Import successful (merged)", "QFSilet")
end

local function editQuickFix(selected, basePath)
	local pth = stripString(selected)
	if pth == nil then
		return
	end

	local filePath = basePath .. "/" .. pth .. ".json"

	local fileRead = Utils.getFileRead(filePath)
	local tbl = fn.json_decode(fileRead)

	if tbl == nil then
		return
	end

	local cleanedTbl, title = Utils.cleanupItems(tbl)

	if #cleanedTbl.qf.items == 0 then
		return
	end

	Utils.writeToFile(cleanedTbl, Constant.defaults.base_path .. "/" .. title .. ".json")

	fn.setqflist({}, " ", cleanedTbl.qf)
	vim.cmd("copen")

	Utils.info("Import successful", "QFSilet")
end

function M.editOrMergeQuickFix(opts, basePath)
	return {
		["default"] = function(selected, _)
			if #selected > 1 then
				mergeQuickFix(selected, opts, basePath)
			else
				editQuickFix(selected[1], basePath)
			end

			-- if Visual.extmarks.set_extmarks then
			-- 	Visual.update_extmarks()
			-- end
			if Visual.extmarks.set_signs then
				Visual.update_signs()
			end
		end,
		["ctrl-q"] = function(selected, _)
			if #selected > 1 then
				mergeQuickFix(selected, opts, basePath)
			else
				editQuickFix(selected[1], basePath)
			end
		end,
	}
end

function M.deleteItem(basePath)
	return {
		["ctrl-x"] = function(selected, _)
			local sel = stripString(selected[1])
			if sel == nil then
				return
			end

			local filePath = basePath .. "/" .. sel .. ".json"

			if Utils.isFile(filePath) then
				local cmd = "!rm"
				vim.api.nvim_exec(cmd .. " " .. filePath, { output = true })
				vim.cmd("lua require'fzf-lua'.resume()")
			end
		end,
	}
end

function M.mark_defaults(mark_opts)
	return {
		["default"] = function(selected, _)
			local sel = stripString(selected[1])
			if sel == nil then
				return
			end

			vim.api.nvim_win_set_cursor(0, { mark_opts[sel].line, 1 })
		end,
	}
end

return M
