local Input = require("nui.input")
local Popup = require("nui.popup")
local NuiText = require("nui.text")
local Util = require("qfsilet.utils")
local Event = require("nui.utils.autocmd").event
local Config = require("qfsilet.config").current_configs

local fmt, cmd = string.format, vim.cmd

local M = {}

local function get_current_screen_size()
	local height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus ~= 0 then
		height = height - 1
	end

	local vim_width = vim.o.columns
	local vim_height = height

	return vim_width, vim_height
end

local function get_desired_ui_size()
	local total_width_ratio = 0.95 -- Total lebar popup relatif terhadap lebar layar
	local total_height_ratio = 0.4 -- Total tinggi popup relatif terhadap tinggi layar

	local vim_width, vim_height = get_current_screen_size()

	local total_width = math.floor(vim_width * total_width_ratio + 0.3)
	local total_height = math.floor(vim_height * total_height_ratio + 0.3)
	local initial_col = math.floor((vim_width - total_width) / 2 + 0.3) + 2
	local initial_row = math.floor((vim_height - total_height) / 2 + 0.3) - 11

	return initial_col, initial_row
end

local function get_desired_popup_size()
	local vim_width, vim_height = get_current_screen_size()

	local width = math.floor(vim_width / 3.5 + 4)
	local height = math.floor(vim_height / 3 - 5)

	return width, height
end

local function h(name)
	return vim.api.nvim_get_hl(0, { name = name })
end

vim.api.nvim_set_hl(0, "Botol", { bg = h("NormalFloat").bg, bold = true, fg = h("Function").fg })
-- vim.api.nvim_set_hl(0, "BotolIcon", { fg = "green", bold = true })
-- vim.api.nvim_set_hl(0, "BotolNormal", { fg = "black", bg = "white", bold = true })
-- vim.api.nvim_set_hl(0, "BotolFloatNormal", { fg = "black", bg = "white", bold = true })

function M.input(func, text_top_msg)
	if vim.bo.filetype == "qf" then
		cmd.wincmd("p")
	end
	local input_opts = {
		position = "50%",
		relative = "editor",
		size = {
			width = 60,
			height = 20,
		},
		border = {
			style = "single",
			padding = { top = 1, bottom = 1, left = 1, right = 1 },
			text = {
				top = fmt("[%s %s]", Config.popup.icon_note, text_top_msg),
				top_align = "center",
			},
		},
		win_options = { winhighlight = Config.popup.winhighlight },
	}

	-- local done = false
	local input = Input(input_opts, {
		prompt = "  ",
		on_submit = function(value)
			func(value)
			-- done = true
		end,
	})

	input:mount()

	-- vim.wait(5, function() end)

	-- unmount component when cursor leaves buffer
	-- input:on(Event.BufLeave, function()
	-- 	input:unmount()
	-- end)
	input:map("n", "<Esc>", function()
		input:unmount()
	end, { noremap = true })
	input:map("n", "<c-c>", function()
		input:unmount()
	end, { noremap = true })

	input:map("n", "<c-k>", function() end, { noremap = true })
	input:map("n", "<c-j>", function() end, { noremap = true })
	input:map("n", "<c-l>", function() end, { noremap = true })
	input:map("n", "<c-h>", function() end, { noremap = true })
	input:map("n", "<c-w>", function() end, { noremap = true })
	input:map("i", "<c-w>", function() end, { noremap = true })

	-- vim.fn.wait(1000, function()
	-- 	return done
	-- end)
end

function M.popup(fname_path, IsGlobal, base_path)
	IsGlobal = IsGlobal or false

	local top_ext_msg = IsGlobal and Config.popup.title_global or Config.popup.title_local

	local col, row = get_desired_ui_size()
	local width, height = get_desired_popup_size()

	local pop_opts = {
		position = { row = row, col = col },
		size = { width = width, height = height },
		relative = "cursor",
		enter = true,
		focusable = true,
		zindex = 50,
		win_options = { foldcolumn = "0", winhighlight = Config.popup.winhighlight },
		buf_options = {
			buflisted = false,
			buftype = "nofile",
			swapfile = false,
			filetype = Config.popup.filetype,
			modeline = false,
		},
		border = {
			padding = { top = 2, bottom = 2, left = 3, right = 3 },
			style = "rounded",
			highlight = Config.popup.winhighlight,
			text = {
				top = NuiText(fmt(" %s ", top_ext_msg), Config.popup.higroup_title),
				top_align = "center",
			},
		},
	}

	if not IsGlobal then
		pop_opts.relative = "editor"
		pop_opts.position = "50%"
		pop_opts.size = "70%"
	end

	local popup = Popup(pop_opts)

	local trim = function(pattern)
		local save = vim.fn.winsaveview()
		cmd(string.format("keepjumps keeppatterns silent! %s", pattern))
		vim.fn.winrestview(save)
	end

	popup:on({ Event.BufLeave, Event.QuitPre }, function()
		trim([[%s/\($\n\s*\)\+\%$//]])
		trim([[%s/\s\+$//e]])

		vim.cmd("silent! wq! " .. fname_path)

		if base_path and vim.fn.getfsize(fname_path) <= 1 then
			Util.rmdir(base_path)
		end

		popup:unmount()
	end)

	popup:map("n", { "<Esc>", "q" }, function()
		trim([[%s/\($\n\s*\)\+\%$//]])
		trim([[%s/\s\+$//e]])

		vim.cmd("silent! wq! " .. fname_path)

		if base_path and vim.fn.getfsize(fname_path) <= 1 then
			Util.rmdir(base_path)
		end

		popup:unmount()
	end, { noremap = true })

	popup:mount()
end

return M
