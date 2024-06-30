local fn = vim.fn

local Constant = require("qfsilet.constant")
local Utils = require("qfsilet.utils")
local Visual = require("qfsilet.marks.visual")
local UtilsFzf = require("qfsilet.fzf.utils")

local M = {}

local function mergeQuickFix(selected, opts, basePath)
	local tbl = {}

	if type(selected) == "table" then
		for _, sel in pairs(selected) do
			local pth = UtilsFzf.stripString(sel)
			local filePath = basePath .. "/" .. pth .. ".json"

			local fileRead = Utils.getFileRead(filePath)
			local jsonTbl = Utils.json_decode(fileRead)
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
	local pth = UtilsFzf.stripString(selected)
	if pth == nil then
		return
	end

	local filePath = basePath .. "/" .. pth .. ".json"

	local fileRead = Utils.getFileRead(filePath)
	local tbl = Utils.json_decode(fileRead)

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
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local filePath = basePath .. "/" .. sel .. ".json"

			if Utils.isFile(filePath) then
				local cmd = "!rm"
				vim.cmd(cmd .. " " .. filePath)
				vim.cmd("lua require'fzf-lua'.resume()")
			end
		end,
	}
end

function M.mark_defaults(buffer)
	return {
		["default"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.stripString(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local bufnr = string.match(text, "%[(%d*)%]")
				local mark = string.match(text, "^(%w*)%s")
				local nr = tonumber(bufnr)
				for k, x in pairs(buffer) do
					if k == nr then
						local found_ls = Utils.find_win_ls(bufnr)
						local locate = x.placed_marks[mark]
						if found_ls.found then
							vim.api.nvim_set_current_win(found_ls.winid)
						else
							vim.cmd("e " .. locate.filename)
						end
						vim.api.nvim_win_set_cursor(0, { locate.line, locate.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-v"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.stripString(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local bufnr = string.match(text, "%[(%d*)%]")
				local mark = string.match(text, "^(%w*)%s")
				local nr = tonumber(bufnr)
				for k, x in pairs(buffer) do
					if k == nr then
						local locate = x.placed_marks[mark]
						vim.cmd("vsplit " .. locate.filename)
						vim.api.nvim_win_set_cursor(0, { locate.line, locate.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-s"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.stripString(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local bufnr = string.match(text, "%[(%d*)%]")
				local mark = string.match(text, "^(%w*)%s")
				local nr = tonumber(bufnr)
				for k, x in pairs(buffer) do
					if k == nr then
						local locate = x.placed_marks[mark]
						vim.cmd("split " .. locate.filename)
						vim.api.nvim_win_set_cursor(0, { locate.line, locate.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,
	}
end

return M
