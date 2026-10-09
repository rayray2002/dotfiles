-- Debugging Python: debugpy runs from Nix (vim.g.dots_debugpy_python, set by
-- modules/neovim.nix); the program runs in the project's own env
-- (dots.python), so nothing has to be installed in each env.
local dap = require("dap")
local dp = require("dap-python")

dp.setup(vim.g.dots_debugpy_python)
dp.test_runner = "pytest"
dp.resolve_python = function()
  return require("dots.python").current().python or "python3"
end

local function args()
  return vim.split(vim.fn.input("args: "), " ", { trimempty = true })
end

-- dap-python brings "file", "file with arguments", "attach remote", ...
vim.list_extend(dap.configurations.python, {
  {
    type = "python", request = "launch", name = "Module (python -m …)",
    module = function() return vim.fn.input("module: ", "scripts.") end,
    args = args, cwd = "${workspaceFolder}", console = "integratedTerminal",
  },
  {
    -- e.g. the GPU solver server started with: python -m debugpy --listen 5678 scripts/solver_server.py
    type = "python", request = "attach", name = "Attach to debugpy (localhost)",
    connect = { host = "127.0.0.1", port = function() return tonumber(vim.fn.input("port: ", "5678")) end },
    justMyCode = false,
  },
})

require("dap-view").setup({ winbar = { controls = { enabled = true } } })
dap.listeners.before.attach.dots = function() require("dap-view").open() end
dap.listeners.before.launch.dots = function() require("dap-view").open() end

local map = vim.keymap.set
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "breakpoint" })
map("n", "<leader>dB", function() dap.set_breakpoint(vim.fn.input("condition: ")) end, { desc = "conditional breakpoint" })
map("n", "<leader>dc", dap.continue, { desc = "start / continue" })
map("n", "<leader>do", dap.step_over, { desc = "step over" })
map("n", "<leader>di", dap.step_into, { desc = "step into" })
map("n", "<leader>dO", dap.step_out, { desc = "step out" })
map("n", "<leader>dC", dap.run_to_cursor, { desc = "run to cursor" })
map("n", "<leader>dl", dap.run_last, { desc = "rerun last" })
map("n", "<leader>dt", dp.test_method, { desc = "debug test under cursor" })
map("n", "<leader>dT", dp.test_class, { desc = "debug test class" })
map("x", "<leader>ds", dp.debug_selection, { desc = "debug selection" })
map("n", "<leader>dr", dap.repl.toggle, { desc = "debug REPL" })
map("n", "<leader>du", function() require("dap-view").toggle() end, { desc = "debug view" })
map("n", "<leader>dq", dap.terminate, { desc = "stop" })
