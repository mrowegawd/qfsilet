local Input = require("nui.input")
local Popup = require("nui.popup")
local Util = require("qfsilet.utils")
local Event = require("nui.utils.autocmd").event
local Config = require("qfsilet.config").current_configs

local fmt, cmd = string.format, vim.cmd

local M = {}

-- Fungsi untuk mendapatkan ukuran layar saat ini
local function get_current_screen_size()
	local height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus ~= 0 then
		height = height - 1
	end

	local vim_width = vim.o.columns
	local vim_height = height

	return vim_width, vim_height
end

-- Fungsi untuk mendapatkan ukuran UI yang diinginkan
local function get_desired_ui_size()
	local total_width_ratio = 0.95 -- Total lebar popup relatif terhadap lebar layar
	local total_height_ratio = 0.4 -- Total tinggi popup relatif terhadap tinggi layar

	local vim_width, vim_height = get_current_screen_size()

	local total_width = math.floor(vim_width * total_width_ratio + 0.3)
	local total_height = math.floor(vim_height * total_height_ratio + 0.3)
	local initial_col = math.floor((vim_width - total_width) / 2 + 0.3) + 8
	local initial_row = math.floor((vim_height - total_height) / 2 + 0.3) - 5

	return initial_col, initial_row
end

-- Fungsi untuk mendapatkan ukuran popup yang diinginkan
local function get_desired_popup_size()
	local vim_width, vim_height = get_current_screen_size()

	local width = math.floor(vim_width / 2 + 4)
	local height = math.floor(vim_height / 2 - 5)

	return width, height
end

-- Fungsi untuk menampilkan input
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
				top = fmt(" [%s %s] ", Config.popup.icon_note, text_top_msg),
				top_align = "center",
			},
		},
		win_options = { winhighlight = Config.popup.winhighlight },
	}

	local input = Input(input_opts, {
		prompt = "> ",
		default_value = "",
		on_close = function() end,
		on_submit = function(value)
			func(value)
		end,
	})

	-- mount/open the component
	input:mount()

	-- unmount component when cursor leaves buffer
	input:on(Event.BufLeave, function()
		input:unmount()
	end)
	input:map("n", "<Esc>", function()
		input:unmount()
	end, { noremap = true })
	input:map("n", "<c-c>", function()
		input:unmount()
	end, { noremap = true })
end

-- Fungsi untuk menampilkan popup
function M.popup(fname_path, IsGlobal, base_path)
	IsGlobal = IsGlobal or false

	local top_ext_msg = IsGlobal and "Todo Global" or "Todo Current Project"

	local col, row = get_desired_ui_size()
	local width, height = get_desired_popup_size()

	local pop_opts = {
		position = { row = row, col = col },
		size = { width = width, height = height },
		relative = "cursor",
		enter = true,
		focusable = true,
		zindex = 50,
		win_options = {
			winhighlight = Config.popup.winhighlight,
			foldmethod = "manual",
			foldcolumn = "0",
			foldtext = "",
		},
		buf_options = {
			-- bufhidden = "hide",
			buflisted = false,
			buftype = "nofile",
			swapfile = false,
			filetype = Config.popup.filetype,
			modeline = false,
			formatexpr = 'v:lua.require("orgmode.org.format")()',
		},
		border = {
			padding = { top = 2, bottom = 2, left = 3, right = 3 },
			style = "rounded",
			text = {
				top = fmt(" [ %s %s ] ", Config.popup.icon_note, top_ext_msg),
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

	popup:on(Event.BufLeave, function()
		vim.cmd("silent! wq! " .. fname_path)

		if vim.fn.getfsize(fname_path) <= 1 then
			Util.rmdir(base_path)
		end

		popup:unmount()
	end)

	local trim = function(pattern)
		local save = vim.fn.winsaveview()
		cmd(string.format("keepjumps keeppatterns silent! %s", pattern))
		vim.fn.winrestview(save)
	end

	popup:map("n", { "<Esc>", "q" }, function()
		trim([[%s/\($\n\s*\)\+\%$//]])
		trim([[%s/\s\+$//e]])
		popup:unmount()
	end, { noremap = true })

	popup:mount()
end

return M
