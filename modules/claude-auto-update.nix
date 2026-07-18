{ pkgs, ... }:
let
  flakeDir = "/home/ray/dotfiles";
  hmTarget = "ray@linux";

  # Bump just the claude-code input, then rebuild & activate home-manager.
  # runtimeInputs pins the tools the script needs so it runs under systemd's
  # empty PATH. openssh/cacert let nix reach GitHub over https/git.
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
  systemd.user.services.claude-code-update = {
    Unit.Description = "Update claude-code via the flake input and rebuild home-manager";
    Service = {
      Type = "oneshot";
      ExecStart = "${updateScript}/bin/claude-code-auto-update";
    };
  };

  systemd.user.timers.claude-code-update = {
    Unit.Description = "Daily claude-code update";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;        # catch up if the machine was off at the scheduled time
      RandomizedDelaySec = "1h"; # spread out so we don't hammer GitHub at 00:00
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
