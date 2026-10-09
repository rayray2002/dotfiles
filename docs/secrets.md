# Secrets

Credentials shared across machines are encrypted with [age](https://age-encryption.org)
and committed; each machine decrypts them at activation. Config: `modules/secrets.nix`,
`secrets/`.

## How it works

- Every machine has its own age key, `~/.config/age/dotfiles.key` (mode 600), made on that
  machine by `dots-secret init-host`. Private keys never leave their machine.
- `secrets/recipients.txt` lists the machines' public keys; `secrets/<name>.age` is
  encrypted to all of them.
- A secret declared in the config is decrypted at activation to its target (mode 600). A
  file that was already there is kept once as `<target>.pre-dotfiles`. A machine that
  can't decrypt yet (no key, or not a recipient) gets a warning and still switches.

## Commands

| Command | Does |
|---|---|
| `dots-secret set NAME < file` | encrypt a file as `secrets/NAME.age` (nothing printed) |
| `dots-secret edit NAME` | decrypt to a private temp file, open `$EDITOR`, re-encrypt |
| `dots-secret list` | secrets in the repo |
| `dots-secret init-host` | make this machine's key if missing; print its public key |
| `dots-secret rekey` | re-encrypt every secret to the current recipients |

Commit the `.age` files and `dots-sync`; never commit plaintext.

## Secrets in use

| Name | Target | For |
|---|---|---|
| `netrc` | `~/.netrc` (on snoopy also the real home, for Slurm jobs) | wandb login |
| `huggingface-token` | `$HF_HOME/token` (`~/.cache/huggingface/token` by default) | Hugging Face |

Each switches on by itself once its `.age` file is in the repo. To import them from xarm,
where both are valid (run from `~/dotfiles` on the Mac):

```bash
ssh xarm 'cat ~/.netrc' | dots-secret set netrc
ssh xarm 'cat ~/.cache/huggingface/token' | dots-secret set huggingface-token
git add secrets/*.age && dots-sync "secrets: wandb and Hugging Face"
```

## Adding a secret

```nix
# home/common.nix (or a host's home/hosts/<alias>.nix)
dots.secrets.<name>.target = "${config.home.homeDirectory}/path/to/file";
```

## Adding a machine

1. On it: `dots-secret init-host`, which prints two lines.
2. Add them to `secrets/recipients.txt`, then on a machine that can already decrypt:
   `dots-secret rekey`, commit, `dots-sync`.
