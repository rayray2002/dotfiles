-- Plugins (installed by Nix, all loaded at start; no plugin manager).
local map = vim.keymap.set

-- Theme: Tokyo Night, the palette the prompt and tmux use (modules/theme.nix)
require("tokyonight").setup({ style = "night" })
vim.cmd.colorscheme("tokyonight-night")

-- mini.nvim: icons, statusline, surround (sa/sd/sr), auto-pairs, and text
-- objects incl. af/if (function) and ac/ic (class) from tree-sitter
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
require("mini.statusline").setup()
require("mini.surround").setup()
require("mini.pairs").setup()
local ts = require("mini.ai").gen_spec.treesitter
require("mini.ai").setup({
  n_lines = 500,
  custom_textobjects = {
    f = ts({ a = "@function.outer", i = "@function.inner" }),
    c = ts({ a = "@class.outer", i = "@class.inner" }),
  },
})

-- Never shown by the file finder or text search (open them explicitly if
-- needed): secrets, and folders of data / runs / outputs / vendored code /
-- agent worktrees that would drown the results.
local hidden_from_search = {
  ".git", ".env", ".env.*", "*.age", "*.pem", "*.key", ".netrc", "deepseek.sh",
  "data", "old_data", "runs", "runs_server", "results", "output",
  "legacy", "scratch", "third-party", "third_party", ".claude/worktrees", ".superpowers",
  "__pycache__", "*.pyc",
}

-- snacks.nvim: the finder/picker, plus the big-file guard (tree-sitter and LSP
-- off for huge files), terminal, lazygit, notifications and indent guides
require("snacks").setup({
  bigfile = { enabled = true },
  quickfile = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  indent = { enabled = true, animate = { enabled = false } },
  words = { enabled = true },
  terminal = { enabled = true },
  lazygit = { enabled = true },
  picker = {
    enabled = true,
    sources = {
      files = { hidden = true, exclude = hidden_from_search },
      grep = { hidden = true, exclude = hidden_from_search },
      grep_word = { hidden = true, exclude = hidden_from_search },
    },
  },
})
map("n", "<leader><space>", function() Snacks.picker.smart() end, { desc = "find (smart)" })
map("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "files" })
map("n", "<leader>fF", function() Snacks.picker.files({ hidden = true, ignored = true, exclude = { ".git" } }) end, { desc = "files (everything)" })
map("n", "<leader>fg", function() Snacks.picker.grep() end, { desc = "grep" })
map("n", "<leader>fG", function() Snacks.picker.grep({ hidden = true, ignored = true, exclude = { ".git" } }) end, { desc = "grep (everything)" })
map({ "n", "x" }, "<leader>fw", function() Snacks.picker.grep_word() end, { desc = "grep word / selection" })
map("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "buffers" })
map("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "recent files" })
map("n", "<leader>fd", function() Snacks.picker.diagnostics() end, { desc = "diagnostics" })
map("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "help" })
map("n", "<leader>fk", function() Snacks.picker.keymaps() end, { desc = "keymaps" })
map("n", "<leader>f.", function() Snacks.picker.resume() end, { desc = "resume last search" })
map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "lazygit" })
map("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "changed files" })
map("n", "<leader>gl", function() Snacks.picker.git_log_file() end, { desc = "log of this file" })
map({ "n", "t" }, "<C-/>", function() Snacks.terminal() end, { desc = "terminal" })
map("n", "<leader>tt", function() Snacks.terminal() end, { desc = "terminal" })

-- oil.nvim: a directory is a buffer; edit names to rename/move/delete. `-` = parent dir
require("oil").setup({ view_options = { show_hidden = true }, skip_confirm_for_simple_edits = true })
map("n", "-", "<cmd>Oil<cr>", { desc = "parent directory" })

-- Git: change signs + hunk actions, and diffview for whole-change/branch review
require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function m(mode, lhs, rhs, desc) map(mode, lhs, rhs, { buffer = buf, desc = desc }) end
    m("n", "]h", function() gs.nav_hunk("next") end, "next hunk")
    m("n", "[h", function() gs.nav_hunk("prev") end, "previous hunk")
    m("n", "<leader>gp", gs.preview_hunk, "preview hunk")
    m({ "n", "x" }, "<leader>gr", ":Gitsigns reset_hunk<cr>", "reset hunk")
    m("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "blame line")
  end,
})
require("diffview").setup()
map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "diff working tree" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "history of this file" })
map("n", "<leader>gq", "<cmd>DiffviewClose<cr>", { desc = "close diffview" })

-- Completion: LSP, paths, snippets, buffer words. Enter accepts, Tab cycles.
require("blink.cmp").setup({
  keymap = {
    preset = "enter",
    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
  },
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 300 }, list = { selection = { preselect = false } } },
  signature = { enabled = true },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  fuzzy = { implementation = "prefer_rust" },
})

-- Formatting on demand only (<leader>cf): segment-anysim isn't ruff-formatted,
-- so format-on-save would rewrite whole files of someone else's repo.
require("conform").setup({
  formatters_by_ft = {
    python = { "ruff_organize_imports", "ruff_format" },
    lua = { "stylua" },
    sh = { "shfmt" }, bash = { "shfmt" }, zsh = { "shfmt" },
    json = { "jq" },
  },
  default_format_opts = { lsp_format = "fallback" },
})
map({ "n", "x" }, "<leader>cf", function() require("conform").format({ async = true }) end, { desc = "format (file / selection)" })

-- Markdown reports render in place (headings, tables, checkboxes, code)
require("render-markdown").setup({ file_types = { "markdown" } })
map("n", "<leader>um", "<cmd>RenderMarkdown toggle<cr>", { desc = "toggle markdown rendering" })

-- Claude Code in a side terminal, connected to this Neovim: it sees the
-- current selection and opens its edits as diffs here (accept / deny).
-- Running `claude` in another tmux pane works too: /ide connects it.
require("claudecode").setup({ terminal = { provider = "snacks", split_side = "right", split_width_percentage = 0.4 } })
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "toggle Claude" })
map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "focus Claude" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "resume a Claude session" })
map("x", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "send selection to Claude" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "add this file to Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "accept Claude's diff" })
map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "reject Claude's diff" })

-- which-key: press <leader> and wait to see these groups
require("which-key").setup({ preset = "modern", delay = 400 })
require("which-key").add({
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>c", group = "code" },
  { "<leader>d", group = "debug" },
  { "<leader>r", group = "repl" },
  { "<leader>a", group = "Claude" },
  { "<leader>t", group = "terminal" },
  { "<leader>u", group = "toggle" },
})
