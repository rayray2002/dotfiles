-- Neovim config (modules/neovim.nix installs Neovim, the plugins and the
-- language servers from Nix; this is the Lua side). Docs: docs/neovim.md.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local o = vim.opt
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.mouse = "a"
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 8
o.updatetime = 250
o.timeoutlen = 400
o.termguicolors = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.confirm = true
o.wrap = false
o.clipboard = "unnamedplus"

-- Over ssh (and in tmux) copy goes to the local clipboard through the
-- terminal (OSC 52). Paste comes from Neovim's own register: asking the
-- terminal for its clipboard is slow or blocked.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION or vim.env.TMUX then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
  end
  vim.g.clipboard = {
    name = "osc52 (copy only)",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end

-- Kept from the old config
local map = vim.keymap.set
map("n", ";", ":", { desc = "command line" })
map("i", "jk", "<Esc>")
map("n", "<Esc>", "<cmd>nohlsearch<cr>")
map("n", "<leader>w", "<cmd>write<cr>", { desc = "save" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "quit window" })
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "leave terminal mode" })

-- File types: robot descriptions are XML, ROS interfaces get their own type,
-- PDDL is highlighted with the Common Lisp grammar (no PDDL grammar exists).
vim.filetype.add({
  extension = {
    xacro = "xml", urdf = "xml", sdf = "xml", launch = "xml",
    srv = "rosmsg", msg = "rosmsg", action = "rosmsg",
    pddl = "pddl",
  },
})
vim.treesitter.language.register("commonlisp", "pddl")

-- Tree-sitter highlighting and indentation for every file type that has a
-- parser (parsers come from Nix; snacks.bigfile turns this off for huge files).
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      local ok, ts = pcall(require, "nvim-treesitter")
      if ok and ts.indentexpr then
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end
  end,
})

-- Briefly highlight what was yanked
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

require("dots.python")
require("dots.plugins")
require("dots.lsp")
require("dots.dap")
require("dots.repl")
