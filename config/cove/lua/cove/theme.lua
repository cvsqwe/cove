-- Тема Cove: цвета из палитры шелла (~/.cache/cove/palette.json пишет services/Recolor.qml),
-- при смене обоев файл переписывается — тема перекрашивается на лету.
local M = {}
M.path = vim.fn.expand("~/.cache/cove/palette.json")

local fallback = {
  crust = "#11111b", mantle = "#181825", base = "#1e1e2e", surface0 = "#313244", surface1 = "#45475a",
  surface2 = "#585b70", overlay0 = "#6c7086", overlay1 = "#7f849c", subtext0 = "#a6adc8", subtext1 = "#bac2de",
  text = "#cdd6f4", accent = "#cba6f7", accent2 = "#89b4fa", red = "#f38ba8", peach = "#fab387",
  yellow = "#f9e2af", green = "#a6e3a1", teal = "#94e2d5", lavender = "#b4befe", pink = "#f5c2e7", light = false,
}

function M.load()
  local f = io.open(M.path, "r")
  if not f then return fallback end
  local ok, p = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(p) == "table" and vim.tbl_extend("keep", p, fallback) or fallback
end

function M.apply()
  local c = M.load()
  M.c = c
  vim.o.background = c.light and "light" or "dark"
  local hl = function(name, spec) vim.api.nvim_set_hl(0, name, spec) end
  local link = function(name, to) vim.api.nvim_set_hl(0, name, { link = to }) end

  -- интерфейс
  hl("Normal", { fg = c.text, bg = c.base })
  hl("NormalNC", { fg = c.text, bg = c.base })
  hl("NormalFloat", { fg = c.text, bg = c.mantle })
  hl("FloatBorder", { fg = c.surface2, bg = c.mantle })
  hl("FloatTitle", { fg = c.accent, bg = c.mantle, bold = true })
  hl("CursorLine", { bg = c.mantle })
  hl("CursorLineNr", { fg = c.accent, bold = true })
  hl("LineNr", { fg = c.surface2 })
  hl("SignColumn", { bg = c.base })
  hl("Visual", { bg = c.surface1 })
  hl("Search", { fg = c.base, bg = c.yellow })
  hl("IncSearch", { fg = c.base, bg = c.accent })
  hl("CurSearch", { fg = c.base, bg = c.accent })
  hl("MatchParen", { fg = c.accent, bold = true, underline = true })
  hl("WinSeparator", { fg = c.crust, bg = c.base })
  hl("VertSplit", { fg = c.crust })
  hl("EndOfBuffer", { fg = c.base })
  hl("NonText", { fg = c.surface1 })
  hl("Whitespace", { fg = c.surface1 })
  hl("Folded", { fg = c.subtext0, bg = c.mantle })
  hl("Pmenu", { fg = c.subtext1, bg = c.mantle })
  hl("PmenuSel", { fg = c.text, bg = c.surface0, bold = true })
  hl("PmenuSbar", { bg = c.mantle })
  hl("PmenuThumb", { bg = c.surface1 })
  hl("PmenuKind", { fg = c.accent2, bg = c.mantle })
  hl("PmenuExtra", { fg = c.overlay1, bg = c.mantle })
  hl("WildMenu", { fg = c.base, bg = c.accent })
  hl("StatusLine", { fg = c.subtext1, bg = c.crust })
  hl("StatusLineNC", { fg = c.overlay0, bg = c.crust })
  hl("TabLineFill", { bg = c.crust })
  hl("Title", { fg = c.accent, bold = true })
  hl("Directory", { fg = c.accent2 })
  hl("ErrorMsg", { fg = c.red, bold = true })
  hl("WarningMsg", { fg = c.yellow })
  hl("MoreMsg", { fg = c.accent })
  hl("Question", { fg = c.accent })
  hl("ModeMsg", { fg = c.subtext0 })
  hl("QuickFixLine", { bg = c.surface0, bold = true })

  -- код
  hl("Comment", { fg = c.overlay1, italic = true })
  hl("Constant", { fg = c.peach })
  hl("String", { fg = c.green })
  hl("Character", { fg = c.teal })
  hl("Number", { fg = c.peach })
  hl("Boolean", { fg = c.peach })
  hl("Identifier", { fg = c.text })
  hl("Function", { fg = c.accent2 })
  hl("Statement", { fg = c.accent })
  hl("Keyword", { fg = c.accent })
  hl("Conditional", { fg = c.accent })
  hl("Repeat", { fg = c.accent })
  hl("Operator", { fg = c.teal })
  hl("PreProc", { fg = c.pink })
  hl("Type", { fg = c.yellow })
  hl("Special", { fg = c.teal })
  hl("Delimiter", { fg = c.overlay1 })
  hl("Underlined", { fg = c.accent2, underline = true })
  hl("Todo", { fg = c.base, bg = c.yellow, bold = true })
  hl("Error", { fg = c.red })
  link("@variable", "Identifier")
  hl("@variable.builtin", { fg = c.red })
  hl("@variable.parameter", { fg = c.lavender })
  hl("@variable.member", { fg = c.lavender })
  hl("@property", { fg = c.lavender })
  link("@function", "Function")
  link("@function.call", "Function")
  hl("@function.builtin", { fg = c.peach })
  link("@function.method", "Function")
  hl("@constructor", { fg = c.yellow })
  link("@keyword", "Keyword")
  hl("@keyword.return", { fg = c.pink })
  hl("@keyword.function", { fg = c.accent })
  link("@type", "Type")
  hl("@type.builtin", { fg = c.yellow, italic = true })
  link("@string", "String")
  hl("@string.escape", { fg = c.pink })
  link("@number", "Number")
  link("@boolean", "Boolean")
  link("@constant", "Constant")
  hl("@constant.builtin", { fg = c.peach })
  link("@operator", "Operator")
  hl("@punctuation", { fg = c.overlay1 })
  link("@comment", "Comment")
  hl("@tag", { fg = c.accent })
  hl("@tag.attribute", { fg = c.yellow, italic = true })
  hl("@tag.delimiter", { fg = c.overlay1 })
  hl("@markup.heading", { fg = c.accent, bold = true })
  hl("@markup.link", { fg = c.accent2, underline = true })
  hl("@markup.raw", { fg = c.green })
  hl("@markup.strong", { bold = true })
  hl("@markup.italic", { italic = true })

  -- диагностика, git, автодополнение
  hl("DiagnosticError", { fg = c.red })
  hl("DiagnosticWarn", { fg = c.yellow })
  hl("DiagnosticInfo", { fg = c.accent2 })
  hl("DiagnosticHint", { fg = c.teal })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
  hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
  hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.accent2 })
  hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.teal })
  hl("DiagnosticVirtualTextError", { fg = c.red, bg = c.mantle, italic = true })
  hl("DiagnosticVirtualTextWarn", { fg = c.yellow, bg = c.mantle, italic = true })
  hl("DiagnosticVirtualTextInfo", { fg = c.accent2, bg = c.mantle, italic = true })
  hl("DiagnosticVirtualTextHint", { fg = c.teal, bg = c.mantle, italic = true })
  hl("GitSignsAdd", { fg = c.green })
  hl("GitSignsChange", { fg = c.yellow })
  hl("GitSignsDelete", { fg = c.red })
  hl("DiffAdd", { bg = c.surface0, fg = c.green })
  hl("DiffChange", { bg = c.surface0 })
  hl("DiffDelete", { fg = c.red })
  hl("BlinkCmpMenu", { fg = c.subtext1, bg = c.mantle })
  hl("BlinkCmpMenuBorder", { fg = c.surface2, bg = c.mantle })
  hl("BlinkCmpMenuSelection", { bg = c.surface0, bold = true })
  hl("BlinkCmpLabelMatch", { fg = c.accent, bold = true })
  hl("BlinkCmpKind", { fg = c.accent2 })
  hl("BlinkCmpDoc", { bg = c.mantle })
  hl("BlinkCmpDocBorder", { fg = c.surface2, bg = c.mantle })
  hl("FzfLuaNormal", { fg = c.text, bg = c.mantle })
  hl("FzfLuaBorder", { fg = c.surface2, bg = c.mantle })
  hl("FzfLuaTitle", { fg = c.accent, bg = c.mantle, bold = true })
  hl("FzfLuaCursorLine", { bg = c.surface0 })

  -- свои части интерфейса (ui/*)
  hl("CoveBar", { fg = c.subtext0, bg = c.crust })
  hl("CoveBarLogo", { fg = c.accent, bg = c.crust, bold = true })
  hl("CoveBarMenu", { fg = c.subtext1, bg = c.crust })
  hl("CoveTab", { fg = c.overlay1, bg = c.crust })
  hl("CoveTabActive", { fg = c.text, bg = c.base, bold = true })
  hl("CoveTabAccent", { fg = c.accent, bg = c.base })
  hl("CoveTabModified", { fg = c.peach, bg = c.crust })
  hl("CoveTabActiveModified", { fg = c.peach, bg = c.base })
  hl("CoveTabClose", { fg = c.overlay0, bg = c.crust })
  hl("CoveTabActiveClose", { fg = c.subtext0, bg = c.base })
  hl("CoveStatus", { fg = c.subtext0, bg = c.crust })
  hl("CoveStatusAccent", { fg = c.crust, bg = c.accent, bold = true })
  hl("CoveStatusDim", { fg = c.overlay0, bg = c.crust })
  hl("CoveStatusError", { fg = c.red, bg = c.crust })
  hl("CoveStatusWarn", { fg = c.yellow, bg = c.crust })
  hl("CoveStatusAction", { fg = c.accent, bg = c.crust, bold = true })
  hl("CoveTree", { fg = c.subtext1, bg = c.mantle })
  hl("CoveTreeTitle", { fg = c.accent, bg = c.mantle, bold = true })
  hl("CoveTreeDir", { fg = c.text, bg = c.mantle, bold = true })
  hl("CoveTreeDim", { fg = c.overlay0, bg = c.mantle })
  hl("CoveTreeActive", { fg = c.accent, bg = c.mantle, bold = true })
  hl("CoveTreeModified", { fg = c.peach, bg = c.mantle })
  hl("CoveTreeCursor", { bg = c.surface0 })
  hl("CoveDashLogo", { fg = c.accent, bold = true })
  hl("CoveDashTitle", { fg = c.text, bold = true })
  hl("CoveDashItem", { fg = c.subtext1 })
  hl("CoveDashKey", { fg = c.overlay1 })
  hl("CoveDashIcon", { fg = c.accent2 })
  hl("CoveDashDim", { fg = c.overlay0 })

  vim.g.terminal_color_0 = c.surface1;  vim.g.terminal_color_8 = c.surface2
  vim.g.terminal_color_1 = c.red;       vim.g.terminal_color_9 = c.red
  vim.g.terminal_color_2 = c.green;     vim.g.terminal_color_10 = c.green
  vim.g.terminal_color_3 = c.yellow;    vim.g.terminal_color_11 = c.yellow
  vim.g.terminal_color_4 = c.accent2;   vim.g.terminal_color_12 = c.accent2
  vim.g.terminal_color_5 = c.accent;    vim.g.terminal_color_13 = c.accent
  vim.g.terminal_color_6 = c.teal;      vim.g.terminal_color_14 = c.teal
  vim.g.terminal_color_7 = c.subtext1;  vim.g.terminal_color_15 = c.subtext0

  vim.g.colors_name = "cove"
  vim.api.nvim_exec_autocmds("User", { pattern = "CoveTheme" })
  vim.cmd.redrawstatus({ bang = true })
  vim.cmd.redrawtabline()
end

-- следим за файлом палитры: шелл переписал — перекрашиваемся
function M.watch()
  local dir = vim.fn.fnamemodify(M.path, ":h")
  vim.fn.mkdir(dir, "p")
  local w = vim.uv.new_fs_event()
  if not w then return end
  local pending = false
  w:start(dir, {}, function(_, fname)
    if fname ~= "palette.json" or pending then return end
    pending = true
    vim.defer_fn(function() pending = false; M.apply() end, 150)
  end)
end

function M.setup()
  M.apply()
  M.watch()
end

return M
