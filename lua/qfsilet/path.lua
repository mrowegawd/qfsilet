local Util = require("qfsilet.utils")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")

local M = {}

local function init(isGlobal, isLoadJson)
	isGlobal = isGlobal or false
	isLoadJson = isLoadJson or false

	if not Util.is_dir(Config.save_dir) then
		Util.create_dir(Config.save_dir)
	end

	Constant.defaults.base_hash = Util.get_hash_note(vim.loop.fs_realpath(vim.loop.cwd()))
	local base_path = Util.get_base_path_root(Config.save_dir, isGlobal)

	Constant.defaults.base_path = base_path .. "_" .. Constant.defaults.base_hash

	local fn_name = Config.file_spec.name .. "_" .. Util.root_path_basename()
	if Config.file_spec.ext_file then
		fn_name = fn_name .. "." .. Config.file_spec.ext_file
	end

	Constant.defaults.note_path = Constant.defaults.base_path .. "/" .. fn_name

	if isGlobal then
		Constant.defaults.base_path = Config.save_dir .. "/__global_qf"

		Constant.defaults.note_path = Constant.defaults.base_path .. "/todo_qfglobal"
		if Config.file_spec.ext_file then
			Constant.defaults.note_path = Constant.defaults.note_path .. "." .. Config.file_spec.ext_file
		end

		Constant.defaults.global_note_dir = Constant.defaults.note_path
	end

	-- Do not create any dir path when calling `note/loadqflist()`
	if not isLoadJson then
		if not Util.is_dir(Constant.defaults.base_path) then
			Util.create_dir(Constant.defaults.base_path)
		end
	end
end

-- Create path local dir path for todo
function M.init_local()
	init()
end

-- Create path global dir path for todo
function M.init_global()
	init(true)
end

return M
