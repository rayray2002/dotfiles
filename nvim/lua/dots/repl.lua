-- REPL: send lines, selections or `# %%` cells to IPython running in the
-- project's env (plain python if IPython isn't installed there).
local iron = require("iron.core")

local function python_cmd()
  local py = require("dots.python").current().python or "python3"
  vim.fn.system({ py, "-c", "import IPython" })
  if vim.v.shell_error == 0 then
    return { py, "-m", "IPython", "--no-autoindent" }
  end
  return { py, "-i" }
end

iron.setup({
  config = {
    scratch_repl = true,
    repl_definition = {
      python = {
        command = python_cmd,
        format = require("iron.fts.common").bracketed_paste_python,
        block_dividers = { "# %%", "#%%" },
      },
    },
    repl_open_cmd = require("iron.view").split.vertical.botright(0.4),
  },
  keymaps = {
    toggle_repl = "<leader>rr",
    send_line = "<leader>rl",
    visual_send = "<leader>rs",
    send_motion = "<leader>rm",
    send_code_block = "<leader>rc",
    send_code_block_and_move = "<leader>rn",
    send_file = "<leader>rf",
    interrupt = "<leader>ri",
    clear = "<leader>rx",
    exit = "<leader>rq",
  },
  highlight = { italic = true },
  ignore_blank_lines = true,
})
