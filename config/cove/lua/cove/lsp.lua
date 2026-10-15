-- Языковые серверы (автодополнение, ошибки, переходы). Сервер для языка ставится одним кликом:
-- в статусной строке появляется «Установить поддержку …», если он ещё не стоит.
local M = {}

-- filetype → { сервер lspconfig, пакет mason, подпись }
M.servers = {
  python = { "basedpyright", "basedpyright", "Python" },
  lua = { "lua_ls", "lua-language-server", "Lua" },
  javascript = { "ts_ls", "typescript-language-server", "JavaScript" },
  javascriptreact = { "ts_ls", "typescript-language-server", "JavaScript" },
  typescript = { "ts_ls", "typescript-language-server", "TypeScript" },
  typescriptreact = { "ts_ls", "typescript-language-server", "TypeScript" },
  rust = { "rust_analyzer", "rust-analyzer", "Rust" },
  c = { "clangd", "clangd", "C" },
  cpp = { "clangd", "clangd", "C++" },
  go = { "gopls", "gopls", "Go" },
  sh = { "bashls", "bash-language-server", "Bash" },
  bash = { "bashls", "bash-language-server", "Bash" },
  json = { "jsonls", "json-lsp", "JSON" },
  html = { "html", "html-lsp", "HTML" },
  css = { "cssls", "css-lsp", "CSS" },
  markdown = { "marksman", "marksman", "Markdown" },
  toml = { "taplo", "taplo", "TOML" },
  yaml = { "yamlls", "yaml-language-server", "YAML" },
  qml = { "qmlls", nil, "QML" },          -- системный qmlls из Qt
}

local function installed(pkg)
  local ok, reg = pcall(require, "mason-registry")
  return ok and reg.is_installed(pkg)
end

local function has_cmd(name)
  local cfg = vim.lsp.config[name]
  local cmd = cfg and cfg.cmd
  return type(cmd) == "table" and cmd[1] and vim.fn.executable(cmd[1]) == 1
end

-- что предложить установить для этого типа файла (или nil)
function M.suggestion(ft)
  local s = M.servers[ft]
  if not s or not s[2] or not package.loaded["mason-registry"] then return nil end
  if installed(s[2]) or has_cmd(s[1]) then return nil end
  return { label = s[3], pkg = s[2], name = s[1] }
end

function M.install_suggested()
  local s = M.suggestion(vim.bo.filetype)
  if not s then return end
  local reg = require("mason-registry")
  local ok, p = pcall(reg.get_package, s.pkg)
  if not ok then return vim.notify(T("Пакет не найден: ") .. s.pkg, vim.log.levels.ERROR) end
  vim.notify(T("Ставлю поддержку ") .. s.label .. "…")
  p:install():once("closed", vim.schedule_wrap(function()
    if p:is_installed() then
      vim.notify(T("Готово: ") .. s.label)
      vim.lsp.enable(s.name)
      vim.cmd("doautoall FileType")
    else
      vim.notify(T("Не удалось установить ") .. s.label, vim.log.levels.ERROR)
    end
    vim.cmd.redrawstatus()
  end))
end

function M.setup()
  vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = true,   -- редактор всегда в режиме ввода — иначе ошибки бы не обновлялись
    underline = true,
    virtual_text = { prefix = "●", spacing = 3, source = "if_many" },
    float = { border = "rounded", source = "if_many" },
    signs = { text = {
      [vim.diagnostic.severity.ERROR] = "󰅚", [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.INFO] = "󰋽", [vim.diagnostic.severity.HINT] = "󰌶",
    } },
  })
  vim.lsp.config("qmlls", { cmd = { "/usr/lib/qt6/bin/qmlls" } })
  vim.lsp.config("lua_ls", { settings = { Lua = { diagnostics = { globals = { "vim" } } } } })
  local enabled = {}
  for _, s in pairs(M.servers) do
    if not enabled[s[1]] and ((s[2] and installed(s[2])) or has_cmd(s[1])) then
      enabled[s[1]] = true
      vim.lsp.enable(s[1])
    end
  end
  -- подсказка при наведении мыши на ошибку
  vim.o.mousemoveevent = true
end

return M
