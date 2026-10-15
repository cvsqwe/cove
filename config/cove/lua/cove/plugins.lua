-- Готовые библиотеки — только там, где писать своё бессмысленно. Всё грузится лениво.
local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", path })
end
vim.opt.rtp:prepend(path)

-- выбор из списка (палитра команд и т.п.) — через fzf-lua, но саму библиотеку грузим по требованию
vim.ui.select = function(...)
  require("fzf-lua").register_ui_select()
  return vim.ui.select(...)
end

require("lazy").setup({
  -- значки файлов
  { "nvim-mini/mini.icons", lazy = false, config = function()
    require("mini.icons").setup()
    MiniIcons.mock_nvim_web_devicons()
  end },

  -- подсветка синтаксиса
  { "nvim-treesitter/nvim-treesitter", branch = "main", lazy = false, build = ":TSUpdate", config = function()
    local ts = require("nvim-treesitter")
    ts.install({ "lua", "python", "bash", "json", "markdown", "markdown_inline", "javascript", "typescript",
      "tsx", "html", "css", "toml", "yaml", "c", "cpp", "rust", "go", "qmljs", "regex", "diff", "gitcommit" })
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
        -- подсветку включаем после первой отрисовки: разбор правил языка при первом открытии
        -- (QML, TypeScript) занимает сотни мс — файл должен появиться сразу, цвета догонят
        vim.defer_fn(function()
          if not vim.api.nvim_buf_is_valid(ev.buf) then return end
          if pcall(vim.treesitter.start, ev.buf, lang) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          elseif vim.tbl_contains(ts.get_available(), lang) then
            ts.install(lang) -- поставится в фоне, подсветка — при следующем открытии
          end
        end, 1)
      end,
    })
  end },

  -- автодополнение (ядро на Rust)
  { "saghen/blink.cmp", version = "1.*", event = { "InsertEnter", "CmdlineEnter" }, opts = {
    -- подсказки — только в настоящих файлах, не в окнах ввода, дереве и т.п.
    enabled = function() return vim.bo.buftype == "" and vim.b.completion ~= false end,
    keymap = { preset = "enter", ["<Tab>"] = { "select_next", "fallback" }, ["<S-Tab>"] = { "select_prev", "fallback" } },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      menu = { border = "rounded", draw = { columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } } } },
      documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = "rounded" } },
      list = { selection = { preselect = true, auto_insert = false } },
    },
    signature = { enabled = true, window = { border = "rounded" } },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  } },

  -- установщик языковых серверов
  { "mason-org/mason.nvim", cmd = "Mason", event = "VeryLazy", opts = {
    ui = { border = "rounded", icons = { package_installed = "󰄬", package_pending = "󰔟", package_uninstalled = "󰅖" } },
  } },
  { "neovim/nvim-lspconfig", event = { "BufReadPre", "BufNewFile" }, dependencies = { "mason-org/mason.nvim" },
    config = function() require("cove.lsp").setup() end },

  -- поиск файлов, текста, команд
  { "ibhagwan/fzf-lua", cmd = "FzfLua", config = function()
    require("fzf-lua").setup({
      "default-title",
      fzf_colors = true,
      winopts = { height = 0.62, width = 0.66, border = "rounded", backdrop = 70,
        preview = { border = "rounded", layout = "flex", flip_columns = 140, scrollbar = false } },
      files = { prompt = T("Файл › "), cwd_prompt = false, git_icons = false },
      grep = { prompt = T("Текст › ") },
      oldfiles = { prompt = T("Недавние › "), include_current_session = true },
      lsp = { prompt_postfix = " › " },
    })
    require("fzf-lua").register_ui_select()
  end },

  -- git-метки на полях
  { "lewis6991/gitsigns.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {
    signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" }, topdelete = { text = "▔" }, changedelete = { text = "▎" } },
  } },

  -- парные скобки и кавычки
  { "nvim-mini/mini.pairs", event = "InsertEnter", opts = {} },
}, {
  ui = { border = "rounded", title = T(" Cove Code — модули ") },
  install = { colorscheme = { "cove" } },
  checker = { enabled = false },
  change_detection = { enabled = false },
  performance = { rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin", "rplugin" } } },
})
