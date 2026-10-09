-- Per-project Python settings, matched by the longest path prefix of the
-- LSP root (or the current directory). Paths may start with ~.
--   env        micromamba/conda env name, looked up under $MAMBA_ROOT_PREFIX/envs
--   python     explicit interpreter (instead of env)
--   extraPaths import roots the code adds via sys.path (relative to the root)
--   typeChecking basedpyright mode: "off" | "basic" | "standard" | "strict"
local ros = {
  python = "/usr/bin/python3",
  extraPaths = {
    "/opt/ros/humble/lib/python3.10/site-packages",
    "/opt/ros/humble/local/lib/python3.10/dist-packages",
  },
  typeChecking = "basic",
}

return {
  -- ROS 2 package of whole-arm-manipulation (built in ~/dev_ws): system Python 3.10
  vim.tbl_extend("force", ros, { root = "~/whole-arm-manipulation/robot_scripts" }),
  vim.tbl_extend("force", ros, { root = "~/dev_ws" }),
  {
    root = "~/whole-arm-manipulation",
    env = "curobo",
    extraPaths = { "src", ".", "third-party/curobov2/src" },
    typeChecking = "basic", -- lightly typed; sys.path hacks
  },
  {
    root = "~/segment-anysim",
    env = "sam3d-objects",
    extraPaths = { "." },
    typeChecking = "standard",
  },
}
