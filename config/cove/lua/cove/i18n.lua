-- Язык Cove Code. Берётся из ~/.cache/cove/lang (его пишет шелл Quickshell), COVE_LANG перекрывает.
-- T("строка") — перевод; без перевода строка показывается как есть.
local M = {}

local function detect()
  local env = vim.env.COVE_LANG
  if env and env ~= "" then return env end
  local f = io.open(vim.fn.expand("~/.cache/cove/lang"), "r")
  if f then
    local l = vim.trim(f:read("*l") or "")
    f:close()
    if l ~= "" then return l end
  end
  return "ru"
end

M.lang = detect()
local dict = M.lang == "en" and require("cove.i18n_en") or {}

function M.t(s) return dict[s] or s end

_G.T = M.t
return M
