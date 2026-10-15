-- Надёжный клик для своих панелей (стартовый экран, дерево): действие — только на паре
-- «нажал + отпустил на той же строке». Голые «отпускания» (окно открылось под курсором,
-- смена фокуса) игнорируются — иначе срабатывали случайные пункты.
local M = {}

function M.bind(buf, on_click)
  local pressed = nil
  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == 0 then return end
    vim.api.nvim_set_current_win(pos.winid)
    if pos.line > 0 then pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(0, pos.column - 1) }) end
    pressed = (vim.api.nvim_win_get_buf(pos.winid) == buf) and pos.line or nil
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<LeftRelease>", function()
    local pos = vim.fn.getmousepos()
    local ok = pressed and pos.line == pressed and vim.api.nvim_get_current_buf() == buf
    pressed = nil
    if ok then on_click(pos.line) end
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<2-LeftMouse>", "<Nop>", { buffer = buf, silent = true, nowait = true })
end

return M
