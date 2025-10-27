local Utils = require "qfsilet.utils"
local Config = require "qfsilet.config"
local Constant = require "qfsilet.constant"

local M = {}

function M.create_file(filename)
  if not Utils.is_file(filename) then
    Utils.create_file(filename)
  end
end

function M.create_dir(filedir)
  if not Utils.is_dir(filedir) then
    Utils.create_dir(filedir)
  end
end

function M.setup_global_path()
  local config = Config.current_configs

  Constant.defaults.global_qf_dir = config.save_dir .. "/__global_qfsilet_qf"
  Constant.defaults.global_note_dir = config.save_dir .. "/__global_qfsilet_note"

  M.create_dir(Constant.defaults.global_qf_dir)
  M.create_dir(Constant.defaults.global_note_dir)
end

function M.init_constant_path()
  local config = Config.current_configs

  Constant.defaults.base_hash = Utils.get_hash_note(vim.loop.fs_realpath(vim.loop.cwd()))

  local base_path = Utils.get_base_path_root(config.save_dir, false)
  Constant.defaults.base_path = base_path .. "_" .. Constant.defaults.base_hash

  local fn_name = config.file_spec.name .. "_" .. Utils.root_path_basename()
  if config.file_spec.ext_file then
    fn_name = fn_name .. "." .. config.file_spec.ext_file
  end

  Constant.defaults.note_path = Constant.defaults.base_path .. "/" .. fn_name
end

function M.setup_path()
  M.init_constant_path()
end

return M
