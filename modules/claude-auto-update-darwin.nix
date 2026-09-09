{ pkgs, ... }:
let
  flakeDir = "/Users/ray/dotfiles";
  hmTarget = "ray@mac";

  # Bump just the claude-code input, then rebuild & activate home-manager.
  # runtimeInputs pins the tools the script needs so it runs under launchd's
  # minimal PATH. openssh/cacert let nix reach GitHub over https/git.
  # Darwin counterpart of modules/claude-auto-update.nix (systemd timer).
  updateScript = pkgs.writeShellApplication {
    name = "claude-code-auto-update";
    runtimeInputs = with pkgs; [ nix git home-manager openssh cacert coreutils ];
    text = ''
      set -euo pipefail
      cd "${flakeDir}"
      echo "==> bumping claude-code flake input"
      nix flake update claude-code
      echo "==> home-manager switch"
      home-manager switch --flake "${flakeDir}#${hmTarget}"
      echo "==> done"
    '';
  };
in
{
  launchd.agents.claude-code-update = {
    enable = true;
    config = {
      ProgramArguments = [ "${updateScript}/bin/claude-code-auto-update" ];
      # Run daily at 12:00. launchd fires at the next matching wall-clock time;
      # if the Mac is asleep then, it runs on the next wake.
      StartCalendarInterval = [ { Hour = 12; Minute = 0; } ];
      StandardOutPath = "/Users/ray/.cache/claude-code-update.log";
      StandardErrorPath = "/Users/ray/.cache/claude-code-update.log";
    };
  };
}
