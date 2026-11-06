-- AstroNvim, installed by the zellij package as the system-wide Neovim
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
      icons_enabled = true, -- the desktop entry uses a Nerd Font
      pin_plugins = nil,
      update_notifications = true,
    },
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
