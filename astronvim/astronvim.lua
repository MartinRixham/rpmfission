-- AstroNvim, installed by the astronvim package as the system-wide Neovim
-- config (/etc/xdg/nvim/init.lua). Neovim reads it only when the user has no
-- ~/.config/nvim/init.lua (or init.vim), so a user's own config always wins.
-- To customise it, start from the AstroNvim template:
--   git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
--
-- Plugins are installed per user, on first start, into
-- ~/.local/share/nvim/lazy, which needs git and network access.

local data = vim.fn.stdpath "data"
local lazypath = vim.env.LAZY or data .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or vim.uv.fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require("lazy").setup({
  {
    "AstroNvim/AstroNvim",
    version = "^6",
    import = "astronvim.plugins",
    opts = {
      mapleader = " ",
      maplocalleader = ",",
      icons_enabled = true, -- needs a Nerd Font in the terminal, as zellij's desktop entry has
      pin_plugins = nil,
      update_notifications = true,
    },
  },
  -- clangd is the system one from clang-tools-extra, on every architecture
  -- (Mason has no build of it for aarch64 Linux), and is never downloaded by
  -- Mason: it is called by its full path, since Mason puts its own bin
  -- directory first on PATH, and taken out of Mason's install lists.
  {
    "AstroNvim/astrolsp",
    opts = function(_, opts)
      if vim.fn.executable "/usr/bin/clangd" == 1 then
        opts.servers = opts.servers or {}
        table.insert(opts.servers, "clangd")
        opts.config = opts.config or {}
        opts.config.clangd = vim.tbl_deep_extend("force", opts.config.clangd or {}, { cmd = { "/usr/bin/clangd" } })
      end
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(name) return name ~= "clangd" end, opts.ensure_installed or {})
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        local name = type(tool) == "table" and tool[1] or tool
        return name ~= "clangd"
      end, opts.ensure_installed or {})
    end,
  },
} --[[@as LazySpec]], {
  -- The default, stdpath("config"), is the user's ~/.config/nvim. Creating it
  -- there would not stop this config loading, but keep the lockfile with the
  -- plugins it pins.
  lockfile = data .. "/lazy-lock.json",
  install = { colorscheme = { "astrotheme", "habamax" } },
  ui = { backdrop = 100 },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
} --[[@as LazyConfig]])
