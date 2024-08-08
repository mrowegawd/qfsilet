local Utils = require("qfsilet.utils")
local Config = require("qfsilet.config")
local Constant = require("qfsilet.constant")

local M = {}

-- local function create_dir(directory)
-- 	if not Utils.isDir(directory) then
-- 		Utils.create_dir(directory)
-- 	end
-- end

function M.create_file(filename)
	if not Utils.isFile(filename) then
		Utils.create_file(filename)
	end
end

function M.init_constant_path(isGlobal)
	local config = Config.current_configs

	Constant.defaults.base_hash = Utils.get_hash_note(vim.loop.fs_realpath(vim.loop.cwd()))

	local base_path = Utils.get_base_path_root(config.save_dir, isGlobal)
	Constant.defaults.base_path = base_path .. "_" .. Constant.defaults.base_hash

	local fn_name = config.file_spec.name .. "_" .. Utils.root_path_basename()
	if config.file_spec.ext_file then
		fn_name = fn_name .. "." .. config.file_spec.ext_file
	end

	Constant.defaults.note_path = Constant.defaults.base_path .. "/" .. fn_name

	if isGlobal then
		Constant.defaults.base_path = config.save_dir .. "/__global_qf"
		Constant.defaults.note_path = Constant.defaults.base_path .. "/todo_qfglobal"
		if config.file_spec.ext_file then
			Constant.defaults.note_path = Constant.defaults.note_path .. "." .. config.file_spec.ext_file
		end
		Constant.defaults.global_note_dir = Constant.defaults.note_path
	end
end

-- `isglobal` true jika note adalah global note, akan disave di global path
-- `isglobal` false jika note adalah local note, akan disave pada local path
function M.setup_path(isGlobal)
	isGlobal = isGlobal or false

	M.init_constant_path(isGlobal)
	-- create_dir(Constant.defaults.base_path)
end

return M
