local fn = vim.fn

local Utils = require("qfsilet.utils")
local Visual = require("qfsilet.marks.visual")
local UtilsFzf = require("qfsilet.fzf.utils")
local Config = require("qfsilet.config").current_configs

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
		Utils.warn("Not implemented yet, abort it", "QF")
		return
	end

	local action = " " -- (a) append, (r) replace, " "
	local tryIdx = "$"

	local what = {
		idx = tryIdx,
		items = Utils.removeDuplicates(tbl),
		title = opts.prefixTitle .. ":Merged",
	}

	if Utils.isLocList() then
		vim.fn.setloclist(0, {}, " ", {
			nr = "$",
			items = what.items,
			title = what.title,
		})
		vim.cmd(Config.theme_list.quickfix.lopen)
	else
		fn.setqflist({}, action, what)
		vim.cmd(Config.theme_list.quickfix.copen)
	end

	Utils.info("Import has been successfully loaded and merged", "QF")
end

local function editQuickFix(selected, basePath)
	local pth = UtilsFzf.stripString(selected)
	if pth == nil then
		return
	end

	local filePath = basePath .. "/" .. pth .. ".json"

	local fileRead = Utils.getFileRead(filePath)
	local tbl = vim.fn.json_decode(fileRead)

	if tbl == nil then
		return
	end

	local cleanedTbl, title = Utils.cleanupItems(tbl)
	if #cleanedTbl.qf.items == 0 then
		return
	end

	Utils.writeToFile(cleanedTbl, basePath .. "/" .. title .. ".json")

	fn.setqflist({}, " ", cleanedTbl.qf)
	vim.cmd(Config.theme_list.quickfix.copen)

	Utils.info("Import data [" .. title .. "] hash been loaded successfully", "QF")
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
		["alt-q"] = function(selected, _)
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
				local cmd = "silent! !rm"
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
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("e " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
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
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("vsplit " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
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
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("split " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-t"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.stripString(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("tabe " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-x"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.stripString(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for i, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						-- print(vim.inspect(buffer.lists[i]))
						buffer.lists[i] = nil
						Visual.remove_sign(x.bufnr, x.id)
					end
				end
			end

			-- require("fzf-lua").actions.resume()
		end,

		["alt-x"] = function(selected, _)
			local sel = UtilsFzf.stripString(selected[1])
			if sel == nil then
				return
			end

			require("qfsilet.marks").clear_all_marks()
			Utils.info("All marks cleared", "Marks")
		end,

		["alt-q"] = function(selected, _)
			local items = {}
			if #selected > 1 then
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.stripString(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = x.text,
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end
			else
				local sel_text = UtilsFzf.stripString(selected[1])
				if sel_text then
					local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
					local line = string.match(text, ":(%d+):")
					local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
					for _, x in pairs(buffer.lists) do
						local filename_trim = Utils.format_filename(x.filename)
						if
							filename
							and string.match(filename_trim, filename)
							and tonumber(x.line) == tonumber(line)
						then
							items[#items + 1] = {
								bufnr = x.buf,
								text = x.text,
								lnum = x.line,
								col = x.col,
								filename = x.filename,
							}
						end
					end
				end
			end

			if #items > 0 then
				vim.fn.setqflist({}, "r", { title = "Marks-", items = items })
				vim.cmd(Config.theme_list.quickfix.copen)
			end
		end,

		["alt-Q"] = {
			prefix = "select-all+accept",
			fn = function(selected, _)
				local items = {}
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.stripString(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = x.text,
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end

				if #items > 0 then
					vim.fn.setqflist({}, "r", { title = "Marks-", items = items })
					vim.cmd(Config.theme_list.quickfix.copen)
				end
			end,
		},

		["alt-l"] = function(selected, _)
			local items = {}
			if #selected > 1 then
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.stripString(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = x.text,
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end
			else
				local sel_text = UtilsFzf.stripString(selected[1])
				if sel_text then
					local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
					local line = string.match(text, ":(%d+):")
					local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
					for _, x in pairs(buffer.lists) do
						local filename_trim = Utils.format_filename(x.filename)
						if
							filename
							and string.match(filename_trim, filename)
							and tonumber(x.line) == tonumber(line)
						then
							items[#items + 1] = {
								bufnr = x.buf,
								text = x.text,
								lnum = x.line,
								col = x.col,
								filename = x.filename,
							}
						end
					end
				end
			end

			if #items > 0 then
				vim.fn.setloclist(0, {}, " ", {
					nr = "$",
					items = items,
					title = "Marks-",
				})
				vim.cmd(Config.theme_list.quickfix.lopen)
			end
		end,

		["alt-L"] = {
			prefix = "select-all+accept",
			fn = function(selected, _)
				local items = {}
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.stripString(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = x.text,
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end

				if #items > 0 then
					vim.fn.setloclist(0, {}, " ", {
						nr = "$",
						items = items,
						title = "Marks-",
					})
					vim.cmd(Config.theme_list.quickfix.lopen)
				end
			end,
		},
	}
end

return M
