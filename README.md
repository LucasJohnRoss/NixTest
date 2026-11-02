# NixOS test-laptop configuration

A flake-based NixOS + Home Manager setup that reproduces a CachyOS/Hyprland daily driver on a test laptop: Hyprland (Lua config) under UWSM with the **Noctalia** shell and Noctalia Greeter, Limine, Plymouth, LUKS + btrfs, hibernation, Quad9 DNS, Docker, KVM/libvirt and your full app list.

Evaluated successfully against **nixos-unstable of 1 Nov 2026 and Home Manager master of 28 Oct 2026** (Hyprland 0.57.0, Noctalia 5.4.1, Noctalia Greeter 1.7.0).

---

## 1. Repository layout

```
nixos-config/
├── flake.nix                          # entry point: inputs, your personal variables, outputs
├── flake.lock                         # (created on first build) exact pinned versions of inputs
├── hosts/
│   └── test-laptop/
│       ├── configuration.nix          # system-level config (root): boot, hardware, services, users
│       └── hardware-configuration.nix # PLACEHOLDER — replaced by the file generated on the laptop
├── home/
│   └── home.nix                       # Home Manager: apps, shell, CLI tools, user services, dotfile links,
│                                      #   Neovim + language servers, declarative Flatpaks
└── dotfiles/                          # copy your CachyOS ~/.config folders in here
    ├── hypr/        (hyprland.lua — the NixOS-ready version is included)
    ├── noctalia/    (config.toml — included)
    ├── ghostty/  nvim/  yazi/  btop/
    ├── starship.toml
    └── zsh/personal.zsh               # optional: extra zsh config to source
```

**Why split system vs home?** `configuration.nix` holds anything that needs root or affects every user (bootloader, kernel, drivers, daemons, firewall). `home.nix` holds everything about *your* session (apps, shell, dotfiles, user services). When you move to your main machines, `home.nix` and `dotfiles/` carry over almost unchanged; you'll mostly add a new `hosts/<machine>/` folder.

---

## 2. `flake.nix` — the entry point

A flake is a project with declared inputs and outputs, and a lock file that pins the inputs. It's what makes the config reproducible: the same `flake.lock` builds the same system on any machine.

| Section | What it does |
|---|---|
| `description` | Free-text label shown by `nix flake show`. |
| `inputs.nixpkgs` | The package collection and NixOS modules. Set to **`nixos-unstable`** (rolling, like Arch/CachyOS). The comment shows how to switch to the stable `nixos-26.05` branch. |
| `inputs.home-manager` | Home Manager source. `inputs.nixpkgs.follows = "nixpkgs"` forces it to reuse your nixpkgs rather than pulling a second copy, keeping versions consistent. |
| `inputs.nix-flatpak` | The `nix-flatpak` module that makes Flatpaks declarative. `?ref=latest` tracks its newest stable release tag (v0.8.0 at time of writing); `flake.lock` pins the exact commit. It's imported at the top of `home/home.nix`. |
| `outputs` → `let vars = {...}` | **The one place to put personal values**: username, full name, email, hostname, timezone, locale, keyboard layout, and where the repo lives (`flakeDir`). These are passed into every module as `vars`. |
| `nixosConfigurations.${vars.hostname}` | Defines the machine. `nixos-rebuild switch --flake .#nixos-test` builds this attribute. |
| `specialArgs` | Makes `inputs` and `vars` available as function arguments in `configuration.nix`. |
| `modules` | The list of modules merged into one system: your `configuration.nix`, the Home Manager NixOS module, and an inline block configuring Home Manager. |
| Home Manager block | `useGlobalPkgs` (use the system's nixpkgs, including `allowUnfree`), `useUserPackages` (install user packages via `/etc/profiles`), `backupFileExtension` (if a file HM wants to manage already exists, e.g. an old `~/.zshrc`, it's renamed to `.hm-backup` instead of aborting), `extraSpecialArgs` (passes `vars` into `home.nix`), and `users.<you>` (loads `home/home.nix`). |
| `formatter` | `nix fmt` formats all `.nix` files with nixfmt. |

Because Home Manager runs *as a NixOS module*, one rebuild updates both the system and your user environment, and they roll back together.

---

## 3. `hosts/test-laptop/configuration.nix` — system configuration

The file starts with a `let` block containing the **hibernation switch** (`enable`, `swapfile`, `resumeDevice`, `resumeOffset`). It is off by default because the resume offset can only be read once the swapfile exists (see §10). Sections are numbered in the file to match this table:

| # | Section | What it does |
|---|---|---|
| 1 | **Imports** | Pulls in `hardware-configuration.nix`. |
| 2 | **Nix itself** | Enables flakes and the `nix` command; deduplicates the store (`auto-optimise-store`); only root may add extra binary caches (`trusted-users = [ "root" ]` — safer, since a trusted user can point the daemon at any cache); `allowUnfree` for Brave, Claude Code, etc. **`programs.nh`** installs `nh`, a front-end for `nixos-rebuild` that shows a diff of what changes before applying, and runs weekly garbage collection (keeps generations from the last 14 days, minimum 5). **`programs.nix-ld`** provides a fake `/lib64/ld-linux` loader so prebuilt binaries (npm native modules, pip wheels, downloaded CLIs) run; its `libraries` list is **added to** nix-ld's built-in 14 (zlib, libstdc++, openssl, curl…), with common extras commented out — when a binary reports `error while loading shared libraries: libX.so`, find the package providing it and add it there. |
| 3 | **Boot** | **Limine** bootloader in UEFI mode, last 10 generations in the menu (each rebuild = a bootable entry, so you can always boot the previous system). Commented lines switch it to legacy BIOS for an older laptop. `linuxPackages_latest` = newest mainline kernel. **Plymouth** splash; `consoleLogLevel = 3` plus the `quiet`/`udev.log_priority`/`rd.systemd.show_status` params hide boot text. The initrd is systemd-based (now the only option), which handles the LUKS prompt inside Plymouth and resume-from-hibernation. A commented `initrd.kernelModules` line loads the GPU driver early for a sharp LUKS prompt. When hibernation is enabled, `resumeDevice` and `resume_offset=` are added automatically. |
| 4 | **Filesystem, swap & hibernation** | Adds `compress=zstd,noatime` to the `/`, `/home`, `/nix` btrfs subvolumes (these merge with the `subvol=` options from the hardware file). Monthly **btrfs scrub**. **zram** swap at 50% of RAM (CachyOS default) for day-to-day swapping; when hibernation is enabled, the disk **swapfile** is added for the hibernation image (systemd ignores zram for hibernation). |
| 5 | **Power, lid & sleep** | `power-profiles-daemon` (power-saver/balanced/performance, same as CachyOS), `upower` (battery for Noctalia's bar), `fwupd` (firmware updates). **logind**: closing the lid on battery suspends; once hibernation is enabled it becomes **suspend-then-hibernate**, hibernating after `HibernateDelaySec = 1h`. On AC it just suspends; docked it's ignored. Noctalia locks the screen before any suspend/hibernate (`lock_before_suspend`), so no lid bind is needed in `hyprland.lua`. |
| 6 | **Networking & DNS** | NetworkManager (used by nm-applet, nm-connection-editor, wifitui and Proton VPN). **Quad9** (`9.9.9.9`, `149.112.112.112` and IPv6) via **systemd-resolved**. `Domains=~.` makes Quad9 the preferred resolver for every domain so the router's DHCP DNS isn't used; `DNSOverTLS=opportunistic` encrypts to Quad9 where possible without breaking captive portals (set `"true"` to enforce); `FallbackDNS` stops resolved falling back to Cloudflare/Google. Firewall on, with `checkReversePath = "loose"` which Proton VPN's WireGuard needs. |
| 7 | **Locale, time, keyboard** | Timezone, locale and keyboard from `vars`; `console.useXkbConfig` gives the TTY and LUKS prompt the same layout as the greeter (which sets its own `keyboard.layout` in section 9). |
| 8 | **Hardware** | Firmware blobs, 3D acceleration incl. 32-bit (for Wine), commented VA-API drivers for Intel. **PipeWire** with ALSA/Pulse compatibility. **Bluetooth** on at boot plus **Blueman** (manager + tray applet). |
| 9 | **Login screen, Hyprland, Noctalia & desktop plumbing** | **Noctalia Greeter** (`services.displayManager.noctalia-greeter`, replaces SDDM): a greetd greeter styled like Noctalia; it enables greetd, AccountsService and polkit. Its `greeter.toml` is generated from `settings`: **Hyprland (UWSM)** preselected, your user preselected, UK keyboard, Bibata cursor. `passwordlessSyncUsers` lets Noctalia's *Sync to greeter* copy your wallpaper/colours without an admin prompt (appearance only). **Hyprland with UWSM**: UWSM runs Hyprland inside a proper systemd user session, so `graphical-session.target`, XDG autostart and clean logout work. **`programs.noctalia`** installs the Noctalia shell from nixpkgs and runs it as a **systemd user service** on `graphical-session.target` — bar, launcher, notifications, wallpaper, lock screen, idle, polkit agent, screenshots and clipboard history in one program (§5a). Its lock screen uses the existing `login` PAM service, so no `programs.hyprlock`-style PAM entry is needed. The Hyprland module installs `xdg-desktop-portal-hyprland`; the GTK portal is added for file pickers. `NIXOS_OZONE_WL=1` makes Electron/Chromium apps (Brave, Notion, Claude) run natively on Wayland. Polkit, dconf, **gnome-keyring** (Proton VPN and Brave store secrets here; greetd's PAM stack includes `login`, so your greeter login unlocks it) and Seahorse. (nm-applet moved to Home Manager.) |
| 10 | **Files** | **Thunar** with archive and volume plugins, `xfconf` so it saves settings, `gvfs` (trash, network shares, phones), `tumbler` (thumbnails), `udisks2` (backend for udiskie). **AppImage** support with binfmt so `./Something.AppImage` runs directly. The **Flatpak** runtime — which apps get installed is declared in `home/home.nix` (section 10). |
| 11 | **Virtualisation** | **Docker**, socket-activated (starts on first `docker` command, not at boot) with weekly auto-prune. **libvirtd** with KVM-only QEMU, rootless QEMU, **swtpm** (virtual TPM for Windows 11) — OVMF/UEFI firmware is included by default. SPICE USB redirection. (The virt-manager GUI is in `home.nix`.) |
| 12 | **Shell & user** | System-level `programs.zsh.enable` (required for zsh to be a valid login shell) and `users.users.<you>.shell = pkgs.zsh` (makes it your login shell) — both needed, both present. `enableGlobalCompInit = false` stops `compinit` running twice (Home Manager runs it); `pathsToLink = [ "/share/zsh" ]` exposes system packages' completions. Your account with groups: `wheel` (sudo), `networkmanager`, `docker`, `kvm`. Not in `libvirtd`, so virt-manager asks for your password; add the group to skip that. Note `docker` group membership is root-equivalent — `virtualisation.docker.rootless` is the alternative. |
| 13 | **System packages & programs** | Only rescue/admin tools root needs even if your user environment is broken: curl, wget, git, vim, pciutils, usbutils, btrfs-progs, cryptsetup, sbctl. `programs.obs-studio` with `package = null` sets up only the **v4l2loopback virtual camera** kernel module; OBS itself is in `home.nix`. Everything that's an application lives in `home.nix`. |
| 14 | **Fonts** | Noto (incl. CJK and colour emoji), Font Awesome (general icon font), JetBrains Mono Nerd Font and Nerd Font symbols. |
| 15 | **State version** | The release the machine was *first installed* with. It controls data-format defaults, not which version you run — never bump it on upgrades. Match whatever `nixos-generate-config` writes. |

---

## 4. `hosts/test-laptop/hardware-configuration.nix`

Machine-specific and **generated on the laptop**: the GUI installer runs `nixos-generate-config`, which writes it to `/etc/nixos/`, and you copy it into the repo (§8.4). It holds disk UUIDs, `boot.initrd.luks.devices`, btrfs `subvol=` mounts, kernel modules for the disk controller, and CPU microcode. The version in this repo is a placeholder that deliberately stops evaluation with an explanatory message, so you can't install a system with no disks defined. Never hand-write it; regenerate it for each machine.

---

## 5. `home/home.nix` — Home Manager

The `let` block defines **`linkedConfigs`**, the list of `~/.config` folders that are symlinked into `dotfiles/`. They are *out-of-store* symlinks: `~/.config/hypr` points straight at `~/nixos-config/dotfiles/hypr`, so you keep editing your existing configs (including `hyprland.lua`) in place and changes apply immediately without a rebuild. Remove a name from the list if you'd rather manage that app in Nix.

At the top of the module, `imports` loads nix-flatpak's Home Manager module from the flake input (that's why the function arguments include `inputs`); it provides the `services.flatpak` options used in section 10.

| # | Section | What it does |
|---|---|---|
| 1 | **Identity** | Username/home from `vars`; `home.stateVersion` (same "first installed with" rule as the system). |
| 2 | **Packages** | Hyprland tools (libnotify, wl-clipboard, wifitui, nm-connection-editor, pavucontrol, playerctl, brightnessctl — which uses logind, so no `video` group is needed); terminal/CLI (ghostty, btop, ripgrep, fd, unzip, jq, and `tree-sitter`, which is the tree-sitter CLI that nvim-treesitter needs — nixpkgs has no separate `tree-sitter-cli`; Neovim itself is in section 9); the **base-devel equivalent** (gcc, make, binutils, pkg-config, autotools, libtool, cmake, patch); Python 3 with pip + virtualenv, **uv**, Node.js + npm, **Claude Code**; **Wine** (`wineWow64Packages.stable`, the current 32+64-bit package) and winetricks; apps: Mission Center, GNOME Calculator (`gnome-calculator`; the old `gnome.*` package set no longer exists), virt-manager, LibreOffice + British English dictionary, **Brave Origin**, **Proton VPN**, **notion-electron** (the same anechunaev app as your AppImage, now packaged), qBittorrent, VLC, file-roller (archive backend for Thunar). |
| 3 | **Dotfile links** | Creates the `~/.config/<name>` symlinks from `linkedConfigs` — folders, plus your `starship.toml` file. |
| 4 | **Environment** | `TERMINAL=ghostty` (`EDITOR`/`VISUAL=nvim` come from section 9). `~/.npmrc` points `npm -g` at `~/.npm-global` (the Nix store is read-only), and `~/bin` (from your old `.zshrc`), `~/.local/bin` and `~/.npm-global/bin` are added to `PATH`. |
| 5 | **zsh** | Your `.zshrc` without oh-my-zsh — see “Your `.zshrc`, mapped” below. Autosuggestions and syntax highlighting (your two plugins) are built-in options; oh-my-zsh's **git plugin** (your third) is loaded on its own from nixpkgs with the one helper function it needs. Then: your `ls`/`ll`/`lt` eza aliases and bindkeys, your `cd` that lists after changing directory, the NixOS workflow aliases (`rebuild`, `update`, `rebuild-test`, `cleanup`), `cat` → `bat`, and the oh-my-zsh defaults you'd otherwise lose. `dotfiles/zsh/personal.zsh` is still sourced last, if it exists. |
| 6 | **CLI programs** | **git** (name/email from `vars`, `main` default branch, rebase on pull); **tmux** (mouse, vi keys, windows numbered from 1, no Esc delay, 256-colour); **yazi** with the zsh `y` wrapper (config still comes from `dotfiles/yazi`); **zoxide**; **fzf** with zsh keybindings (Ctrl-R history, Ctrl-T files, Alt-C directories) using `fd` so hidden files are included and `.gitignore` is respected; **bat** (TwoDark theme, line numbers, git change markers); **eza** with your flags (`--icons=always --color=always --group-directories-first`, plus git status in `ll`), applied to every eza alias; **starship** prompt (reads your `starship.toml`); **direnv + nix-direnv** (§11, “Dev environments”); **OBS Studio**. Installing these through `programs.*` rather than `home.packages` is what adds the shell integration and writes their config files. |
| 7 | **User services** | systemd user services started with the UWSM session: **playerctld** (remembers the last active media player, so `playerctl play-pause` on your media keys controls whatever you used last), **nm-applet** (`xsession.preferStatusNotifierItems = true` makes it use the tray protocol Noctalia's tray shows), **udiskie** automount (tray icon off; set `tray = "auto"` to show it). |
| 8 | **Look & feel** | Bibata cursor for GTK and Hyprland (hyprcursor), Adwaita-dark GTK theme, `prefer-dark` colour scheme, and virt-manager auto-connecting to `qemu:///system`. |
| 9 | **Neovim + language servers** | Neovim with the language servers your config enables on its wrapper PATH (on NixOS your config skips Mason) — explained in §6. |
| 10 | **Declarative Flatpaks** | Flathub apps, auto-updates and overrides via nix-flatpak — explained in §7. |

### Who starts what (so nothing launches twice)

| Started by | Programs |
|---|---|
| NixOS user service (`programs.noctalia.systemd`) | **noctalia** |
| Home Manager user services | nm-applet, playerctld, udiskie |
| XDG autostart (run by UWSM) | blueman-applet |
| **Your `hyprland.lua`** | nothing — the included version has an empty autostart |

The `hyprland.lua` in `dotfiles/hypr/` is already edited for this: no `exec` lines, Rofi/hyprshot/hyprlock binds switched to Noctalia IPC, no lid bind. On a machine *without* the systemd service, uncomment its `hl.exec_cmd("noctalia")` line instead. NixOS has no `/usr/bin`, so use bare command names in anything you add.

### 5a. Noctalia shell

One program replaces nine: **Waybar** (bar + tray), **Rofi** (launcher), **Dunst** (notifications), **hyprpaper / wallpaper engine** (wallpaper), **hyprlock** (lock screen), **hypridle** (idle), **hyprpolkitagent** (polkit agent), **hyprshot** (screenshots) and **cliphist** (clipboard history, whose picker was Rofi). Noctalia v5 is a native Wayland shell (no Qt/Quickshell); the package and NixOS module come from nixpkgs, so there's no extra flake input.

Its settings are your own TOML in `dotfiles/noctalia/config.toml`, linked to `~/.config/noctalia` like your other dotfiles, so it hot-reloads on save and works unchanged on other distros. Only non-default values are listed: polkit agent on, apps launched as systemd units, screenshots to `~/Images/Screenshots`, wallpapers from `~/Images/Wallpapers`, lock before suspend, and idle (lock 10 min, screens off 11 min, optional suspend at 30 min, disabled). Changes made in Noctalia's Settings window go to `~/.local/state/noctalia/settings.toml`, which wins over the file — copy what you want to keep into `config.toml`.

| Key | Action (`noctalia msg …`) | Was |
|---|---|---|
| Super+R | `panel-toggle launcher` | `rofi -show drun` |
| Super+Shift+V | `panel-toggle clipboard` | cliphist (no picker after Rofi) |
| Super+Shift+L | `session lock` | `scripts/arm-lock.sh` |
| Super+comma | `settings-toggle` | — |
| Print / Shift+Print | `screenshot-region` → clipboard / file | `hyprshot -m region` |
| Super+Print / Super+Shift+Print | `screenshot-fullscreen` → clipboard / file | `hyprshot -m output` |
| Super+Ctrl+Print | `screenshot-region --annotate` | — |

Volume, brightness and media keys keep using `wpctl`, `brightnessctl` and `playerctl`; Noctalia watches PipeWire and the backlight, so its OSD appears for them anyway. Logs: `journalctl --user -u noctalia` and `~/.cache/noctalia/noctalia.log`.

### Your `.zshrc`, mapped

| Old `.zshrc` | Now |
|---|---|
| `export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH` | `home.sessionPath` (`~/bin`, `~/.local/bin`); `/usr/local/bin` doesn't exist on NixOS |
| oh-my-zsh, `ZSH_THEME=""` | Removed; prompt is starship |
| `plugins=(zsh-autosuggestions zsh-syntax-highlighting)` | `autosuggestion.enable`, `syntaxHighlighting.enable` |
| `plugins=(git)` | `programs.zsh.plugins` → oh-my-zsh's `git.plugin.zsh` only (all its `g…` aliases), plus `git_current_branch` |
| `DISABLE_MAGIC_FUNCTIONS="true"` | Not needed: it switched off oh-my-zsh's URL-quoting paste widgets, which aren't loaded any more |
| `COMPLETION_WAITING_DOTS="true"` | Dropped (an oh-my-zsh-only indicator); the completion menu itself is kept |
| `bindkey '^H' …`, `bindkey '^[[8;6u' …` | `initContent`, unchanged |
| `ls` / `ll` / `lt` eza aliases | `shellAliases` + shared flags in `programs.eza` |
| `cd() { builtin cd "$@" && ls }` | `initContent`, placed after the aliases so `ls` is your eza alias |
| `eval "$(starship init zsh)"` | `programs.starship` |
| oh-my-zsh defaults | Re-created: case-insensitive menu completion, Up/Down prefix history search, Home/End/Delete/Ctrl+←→ keys, `WORDCHARS=''` (Ctrl+Backspace stops at `/`), `auto_cd`, `auto_pushd`, `...` → `../..`, `-` → `cd -`, `md`, timestamped history |

---

## 6. Neovim and language servers — `home.nix` section 9

Your Neovim config (in `dotfiles/nvim`) runs on NixOS and on other distros, and decides by itself where language servers come from:

| System | Servers come from | How it decides |
|---|---|---|
| NixOS | `programs.neovim.extraPackages` in `home.nix` | `init.lua` finds `/etc/NIXOS` and skips `lua/config/lsp_install.lua` (Mason) |
| Other distros | Mason, installed on first launch | No `/etc/NIXOS` → Mason runs |
| Override | Either | `NVIM_MASON=1` forces Mason on, `NVIM_MASON=0` off (e.g. standalone Home Manager on another distro) |

On NixOS the Nix packages are the better source anyway: Mason downloads prebuilt binaries that only run through the `nix-ld` shim and aren't pinned by `flake.lock`, while Nix packages are versioned and rolled back with the rest of the system.

**The rule:** every server enabled in `lua/config/lsp_servers.lua` needs its package in `extraPackages`. The list in `home.nix` mirrors that file — enabled there, active here; commented there, commented here — so turning a server on means uncommenting it in both places, then `rebuild`.

| `lsp_servers.lua` key | Package in `home.nix` | Status |
|---|---|---|
| `clangd` | `clang-tools` | Enabled |
| `basedpyright` | `basedpyright` | Enabled |
| `rust_analyzer` | `rust-analyzer` | Enabled — it also needs `cargo`/`rustc`, best from the project's dev shell (§11, “Dev environments”) |
| `marksman` | `marksman` | Enabled |
| `terraformls` | `terraform-ls` | Enabled |
| `stylua` | `stylua` | Enabled — runs as a server (`stylua --lsp`; nixpkgs builds it with LSP support) |
| `lua_ls` | `lua-language-server` | Enabled |
| `bashls`, `yamlls`, `jsonls` | `bash-language-server` (+ `shellcheck`), `yaml-language-server`, `vscode-langservers-extracted` | Commented out in both |
| `sqlls` | — | Its server isn't packaged in nixpkgs; use `sqls` instead (package `sqls`, key `sqls = {}`) |

Further servers you had before (`nixd`, `ruff`, `ts_ls`, `taplo`, `dockerls`, `ansiblels`…) and formatters for conform.nvim's `formatters_by_ft` are listed, commented out, at the end of the section.

**Plugins are not managed by Nix.** Your config installs them with `vim.pack`, Neovim 0.12's built-in plugin manager (nixpkgs has Neovim 0.12.6). What that means in practice:

- **First launch** shows *“These plugins will be installed … Proceed? Yes / No / Always”* — answer **Always**. Plugins go to `~/.local/share/nvim/site/pack/core/opt`.
- `vim.pack` writes **`nvim-pack-lock.json`** into your config folder, which is the repo's `dotfiles/nvim`. Commit it: other machines then install exactly the same plugin versions.
- Several plugins are compiled on install, using tools `home.nix` already provides: treesitter parsers (`tree-sitter` CLI 0.26.1+ and `gcc`, plus `curl` and `tar` from NixOS), telescope-fzf-native and LuaSnip's `jsregexp` (`gcc`, `gnumake`). Telescope's live grep and file search use `ripgrep` and `fd`; `vim.pack` itself needs `git`. All of these are in section 2 or 6 of `home.nix`.
- Updates: `:lua vim.pack.update()`, then commit the changed lockfile.

`sideloadInitLua = true` keeps Home Manager's small generated `init.lua` (which switches off the unused Python, Node, Ruby and Perl providers) out of `~/.config/nvim`, so your linked config is never overwritten.

---

## 7. Declarative Flatpaks — `home.nix` section 10

Uses the `nix-flatpak` Home Manager module, so Flatpaks are listed in Nix like any other package. Installs go into your **user** Flatpak installation. The runtime itself (`services.flatpak.enable`) stays in the system config, because Flatpak needs system-level portal and bubblewrap setup.

| Section | What it does |
|---|---|
| `imports` | Loads `nix-flatpak`'s Home Manager module from the flake input. |
| `packages` | The list of Flathub app IDs to install. **Flathub is added automatically** (no manual `remote-add`). Starts with **Flatseal** (a GUI for reviewing app permissions); commented examples show the format, including pinning an app to a specific commit. Find IDs with `flatpak search <name>` or from the app's flathub.org URL. |
| `uninstallUnmanaged = true` | Fully declarative: anything in your user installation that isn't listed is **removed** on rebuild — delete a line, the app goes. Set it to `false` while experimenting if you want hand-installed Flatpaks to survive. (System-wide Flatpaks aren't touched.) |
| `update.auto` | A weekly systemd timer updates all Flatpaks; updates also run once on each activation. |
| `overrides.settings` | Flatpak permission/environment overrides as Nix. The `global` block gives every sandboxed app your host cursor theme and dark GTK theme on Wayland; the commented line shows a per-app override. These **replace** any hand-made files in `~/.local/share/flatpak/overrides`. |

Installs happen in a systemd user service after activation, so `rebuild` returns before downloads finish. Follow progress with `journalctl --user -fu flatpak-managed-install`.

---

## 8. Installation (GUI installer)

You install in two stages. The GUI installer (Calamares) does what it does well — partitioning, LUKS2 encryption, btrfs — and installs a minimal, console-only NixOS. One `nixos-rebuild` then switches that system to this flake. Allow 1–2 hours, mostly the first build downloading several GB.

| Stage | Result |
|---|---|
| GUI installer | 1 GiB EFI partition at `/boot`; one LUKS2 partition holding btrfs, with the top level mounted at `/` plus `home` and `nix` subvolumes, all `compress=zstd,noatime`; systemd-boot; text login only |
| First flake build (§8.4) | This config: Limine, Plymouth, Noctalia Greeter, Hyprland (UWSM) + Noctalia, every app, Quad9, Docker, libvirt, Flatpaks |
| Afterwards (§9, §10) | libvirt network, hibernation swapfile, the installer's systemd-boot removed |

The installer's subvolumes match the three mount points that `configuration.nix` section 4 adds options to, so the config needs no changes for its layout.

### 8.1 Before you start (on your CachyOS machine)

1. **Fill in `vars` in `flake.nix`.** `username` must be the login name you'll type into the installer, so the password you set there carries over. Keep `hostname = "nixos-test"`, or change every `#nixos-test` below to match.
2. **Copy your dotfiles** into the repo:
   ```bash
   cp -r ~/.config/{ghostty,nvim,yazi,btop,starship.toml} ~/nixos-config/dotfiles/
   ```
   Don't copy `hypr` over the included `dotfiles/hypr/hyprland.lua` (already edited for NixOS + Noctalia), and don't copy `waybar`, `rofi` or `dunst` (no longer used). Put a few wallpaper images on a USB stick for the laptop (§9, one-time setup) — images don't belong in the git repo.
3. **`hyprland.lua` is already done** (§5, “Who starts what”). Your Neovim config needs no changes — it skips Mason on NixOS by itself (§6) — and your old `.zshrc` isn't needed.
4. **Push the repo to a private git repository** (it contains your email):
   ```bash
   cd ~/nixos-config
   git init -b main && git add -A && git commit -m "NixOS test-laptop config"
   git remote add origin git@github.com:<you>/nixos-config.git
   git push -u origin main
   ```
5. **Make the USB stick.** Download the **Graphical ISO** for NixOS 26.05, x86_64, from nixos.org/download (GNOME or Plasma — it's only the live session), check it against the published SHA-256, and write it to a stick of 4 GB or more. Check the stick's name with `lsblk` first; it is erased:
   ```bash
   sha256sum nixos-graphical-*.iso
   sudo dd if=nixos-graphical-26.05-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
6. **Laptop firmware settings** (usually F2, F10 or Del at power-on): **UEFI** boot mode with CSM/Legacy off, **Secure Boot off** (§12 covers turning it back on), and storage mode **AHCI** rather than Intel RST/RAID if the option exists.

### 8.2 The GUI installer

Boot the USB stick (the boot menu is often F12) and take the default entry. In the live desktop, **connect to the network** from the top bar first — the installer downloads packages. The **Install NixOS** window opens by itself; its screens, in order:

| # | Screen | Choose |
|---|---|---|
| 1 | Welcome | **British English** |
| 2 | Location | Region **Europe**, zone **London**; language and number/date format **en_GB.UTF-8** |
| 3 | Keyboard | Layout **English (UK)**, variant **Default**; type `£` and `"` in the test box to check |
| 4 | Users | Your name = `fullName`; **login name = `username` from `flake.nix`**; computer name `nixos-test`; a strong password. Leave **Log in automatically** off. Root: tick **Use the same password for the administrator account**, or set a separate one |
| 5 | Desktop | Scroll to the bottom: **No desktop**. The flake supplies the desktop, and the base install stays small |
| 6 | Unfree software | Leave unticked — the flake allows unfree packages itself |
| 7 | Partitions | See below |
| 8 | Summary | Check the disk is the laptop's internal one → **Install** |

**Partitions (screen 7):**

1. **Storage device:** the internal disk — check its size; it's never the USB stick.
2. **Erase disk.** Everything on it is destroyed.
3. **Swap: No swap.** zram (in the config) handles everyday swapping; hibernation gets a btrfs swapfile in §10.
4. **File system: btrfs.**
5. Tick **Encrypt system** and enter the passphrase twice. You'll type it at every boot, on the UK layout.
6. Check the **After** bar: a 1 GiB **EFI** partition (FAT32, `/boot`) and one **LUKS** partition with btrfs at `/`.

Installation takes 5–15 minutes. At **All done**, tick **Restart now**, click **Done**, and remove the stick when the screen goes dark.

### 8.3 First boot: check what the installer made

The base system boots through systemd-boot to a passphrase prompt, then a text `nixos-test login:` prompt. Log in as your user, get online (Ethernet connects by itself), and confirm the layout:

```bash
nmtui                                   # Wi-Fi: Activate a connection → your network → Back → Quit
ping -c 3 nixos.org

cat /etc/nixos/hardware-configuration.nix
#   expect: boot.initrd.luks.devices."luks-<uuid>"
#           fileSystems "/" btrfs, "/home" with subvol=home, "/nix" with subvol=nix, "/boot" vfat
sudo btrfs subvolume list /             # lists home and nix

ls /dev/mapper                          # write down the luks-<uuid> name — needed in §10
grep stateVersion /etc/nixos/configuration.nix   # expect "26.05"
free -h                                 # note the RAM size — the swapfile size in §10
```

If `/home` or `/nix` is missing from the hardware file, the installer used a different layout: delete that mount point from the `fileSystems` block in `configuration.nix` section 4 before building, or the build stops with an error about a file system with no device.

### 8.4 Switch to your flake

`nixos-rebuild boot` makes your config the default for the next boot without changing the running system, and the installer's system stays in the boot menu as a fallback.

```bash
# 1. git and the GitHub CLI for this session only (flakes aren't enabled on the base system yet)
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git nixpkgs#gh

# 2. Clone. The path must be ~/nixos-config — vars.flakeDir points there
gh auth login            # GitHub.com → HTTPS → Login with a web browser; enter the code on another device
gh repo clone <you>/nixos-config ~/nixos-config
cd ~/nixos-config

# 3. Replace the placeholder with this laptop's hardware config
cp /etc/nixos/hardware-configuration.nix hosts/test-laptop/

# 4. Pin the inputs (writes flake.lock)
nix --extra-experimental-features "nix-command flakes" flake lock

# 5. Build as yourself; --sudo uses sudo only to install the result
NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild boot --sudo --flake ~/nixos-config#nixos-test

# 6. Reboot
exit
sudo reboot
```

- If §8.3 showed a `stateVersion` other than `"26.05"`, use that value in `system.stateVersion` (`configuration.nix`) and `home.stateVersion` (`home.nix`) before step 5.
- **Run step 5 as yourself, not as `sudo nixos-rebuild`.** Nix refuses to read a git repository owned by another user, so a root build of a repo in your home folder fails with `repository … is not owned by current user`. `--sudo` evaluates the flake as you and elevates only the install.
- A `Git tree … is dirty` warning is expected. Step 5 is the long one (several GB from the binary cache). If it stops with an error, nothing has changed: fix the file the error names and run it again.
- At the end it installs **Limine** and puts it first in the UEFI boot order. systemd-boot stays installed as a fallback until §9.
- No GitHub? In place of step 2, copy the folder from a USB stick to `~/nixos-config`.

> **Git gotcha:** flakes in a git repo only see files git knows about. A *new* file (a new module, say) must be `git add`-ed before rebuilding, or Nix reports it as missing. Changes to tracked files are seen without committing.

### 8.5 Install troubleshooting

Every rebuild leaves the previous system bootable, so most problems are undone by picking an older generation in the boot menu; once back in, `sudo nixos-rebuild switch --rollback` makes it the default again.

| Symptom | Cause | Fix |
|---|---|---|
| `hardware-configuration.nix is still the placeholder` | §8.4 step 3 skipped | Copy `/etc/nixos/hardware-configuration.nix` into `hosts/test-laptop/` |
| A `fileSystems` entry has no device | Installer made a different layout | Remove that mount point from section 4's `fileSystems` block (§8.3) |
| `repository … is not owned by current user` | Built with `sudo nixos-rebuild` | Run as yourself with `--sudo` (§8.4 step 5) |
| `experimental feature 'flakes' is disabled` | Only before the first switch | Use the `NIX_CONFIG=…` / `--extra-experimental-features` forms from §8.4 |
| A file you just created `does not exist` | Flakes only see files git tracks | `git add <file>`, then rebuild |
| Black screen, no keybinds, or a Hyprland error bar | `hyprland.lua` missing or broken | Ctrl+Alt+F3 for a text console, fix `~/nixos-config/dotfiles/hypr/hyprland.lua`, then `sudo systemctl restart display-manager` |
| Hyprland runs but no bar, wallpaper or notifications | Noctalia not running, or a bad `config.toml` | `systemctl --user status noctalia`; `journalctl --user -u noctalia -b`; `noctalia config validate ~/.config/noctalia/config.toml`; then `systemctl --user restart noctalia` |
| Greeter doesn't appear (text login or blank screen) | greetd/greeter failed to start | Ctrl+Alt+F3, log in, `journalctl -b -u greetd`; boot the previous generation from Limine if needed |
| No bootable device after a firmware reset | UEFI boot entries wiped | Reinstall the loader from the USB stick — below |

**Reinstalling the loader from the USB stick** (live desktop → terminal; replace `nvme0n1p2` / `nvme0n1p1` with your LUKS and EFI partitions from `lsblk`):

```bash
sudo cryptsetup open /dev/nvme0n1p2 cryptroot
sudo mount -o compress=zstd /dev/mapper/cryptroot /mnt
sudo mount -o subvol=nix,compress=zstd /dev/mapper/cryptroot /mnt/nix
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
sudo reboot
```

**Legacy-BIOS laptop?** (no UEFI option in its firmware) The installer sets up GRUB instead, and Limine must be installed to the disk's boot sector: switch to the commented `biosSupport`/`biosDevice` lines in `configuration.nix`. Tell me if that's the case and I'll adjust these steps.

---

## 9. First login and setup

The new boot goes **Limine menu** (3 s) → **Plymouth** splash with the passphrase prompt → **Noctalia Greeter** with your user and **Hyprland (UWSM)** preselected → **Hyprland** with your `hyprland.lua` and the Noctalia bar. If an error bar appears, fix the file it names — `~/.config/hypr` is your repo's `dotfiles/hypr`, and Hyprland reloads on save.

**Checks** — open a terminal and tick these off:

- [ ] `efibootmgr` — **Limine** is first in `BootOrder`.
- [ ] `systemctl --failed` and `systemctl --user --failed` — 0 units each.
- [ ] `resolvectl status` — **Global** lists the four Quad9 servers, `DNSOverTLS=opportunistic` and `DNS Domain: ~.`; on.quad9.net in Brave says you're using Quad9.
- [ ] `echo $SHELL` ends in `zsh`; `ll` gives your eza listing; Ctrl-R opens fzf history; the starship prompt shows.
- [ ] `ls -l ~/.config/hypr ~/.config/nvim ~/.config/starship.toml` — symlinks into `~/nixos-config/dotfiles/`.
- [ ] `systemctl --user status noctalia udiskie playerctld network-manager-applet` — all `active (running)`.
- [ ] nm-applet and Blueman icons are in Noctalia's tray; `notify-send test` shows a Noctalia toast.
- [ ] Super+Shift+L locks; your password unlocks. Open virt-manager → a Noctalia polkit prompt appears.
- [ ] Print → drag a region → paste it somewhere; Shift+Print saves to `~/Images/Screenshots`.
- [ ] `flatpak list --user` shows **Flatseal** (it installs in the background on first login; follow it with `journalctl --user -fu flatpak-managed-install`).
- [ ] In Neovim, open a `.lua` file and run `:checkhealth vim.lsp` — `lua_ls` and `stylua` are attached, from `/nix/store` paths, and no Mason section appears.
- [ ] Brave Origin, Notion, Proton VPN, LibreOffice, GNOME Calculator and VLC launch from the Noctalia launcher (Super+R).

**One-time setup:**

1. **Launch Neovim once.** Answer **Always** to the plugin-install prompt and wait for the plugins and treesitter parsers to build (a minute or two; `:messages` shows any build error). This writes `dotfiles/nvim/nvim-pack-lock.json`.
2. **Commit this laptop's state.** `hardware-configuration.nix`, `flake.lock` and `nvim-pack-lock.json` are new. The `gh` login lived in the temporary shell, so switch to an SSH key:
   ```bash
   ssh-keygen -t ed25519 -C "nixos-test"
   cat ~/.ssh/id_ed25519.pub        # add on GitHub: Settings → SSH and GPG keys
   cd ~/nixos-config
   git remote set-url origin git@github.com:<you>/nixos-config.git
   git add -A && git commit -m "nixos-test: hardware config and lock files" && git push
   ```
3. **Bring your shell history across:** copy `~/.zsh_history` from CachyOS (USB stick or `scp`) to `~/.local/share/zsh/history`. Both use the same timestamped format.
4. **Start libvirt's NAT network** so VMs get internet: `sudo virsh net-autostart default && sudo virsh net-start default`. virt-manager asks for your password because you're not in the `libvirtd` group; add it to `extraGroups` to skip that.
5. **Test Docker:** `docker run --rm hello-world` (the first command starts the daemon, so it takes a few seconds).
6. **Sign in to Proton VPN.** Credentials go into the GNOME keyring, which your greeter login unlocks.
7. **Update firmware:** `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update`.
8. **Remove the installer's systemd-boot** once Limine has booted the laptop a few times without trouble:
   ```bash
   sudo bootctl remove                       # systemd-boot's files and UEFI entry
   sudo rm -rf /boot/loader /boot/EFI/nixos  # its menu entries and kernel copies
   ls /boot /boot/EFI                        # EFI + limine; EFI/limine
   efibootmgr                                # Limine, and no "Linux Boot Manager"
   ```
   Limine keeps its own files in `/boot/limine` and `/boot/EFI/limine`, which this doesn't touch. Reboot once to confirm, and keep the USB stick for the recovery steps in §8.5.
9. **Set up Noctalia.** Copy wallpapers into `~/Images/Wallpapers` (`mkdir -p ~/Images/{Wallpapers,Screenshots}` first) and pick one from the wallpaper button in the bar. Open Settings with **Super+comma** to adjust the bar, theme and the rest; anything you want to keep, copy from `~/.local/state/noctalia/settings.toml` into `dotfiles/noctalia/config.toml`. Then **Settings → Security → Noctalia Greeter → Sync Now** gives the login screen the same wallpaper and colours (no password prompt, thanks to `passwordlessSyncUsers`). Leave the greeter's *Auto-Sync* off unless you want it to re-sync on every change.

---

## 10. Enable hibernation

Create a swapfile in its own btrfs subvolume, read its offset, then fill in the `hibernation` block at the top of `configuration.nix`. Hibernation stays off until then, because a wrong resume device makes every boot wait for a disk that isn't there.

```bash
# Size it at least equal to your RAM (from §8.3); 16g shown
sudo btrfs subvolume create /swap
sudo btrfs filesystem mkswapfile --size 16g --uuid clear /swap/swapfile
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile     # prints the resume offset
```

Because `/` is the btrfs top level, `/swap` appears immediately and needs no `fileSystems` entry; `mkswapfile` also turns off copy-on-write and compression for the file, as swap requires. Then edit the block — the installer named the LUKS device `luks-<uuid>` (§8.3):

```nix
hibernation = {
  enable = true;
  swapfile = "/swap/swapfile";
  resumeDevice = "/dev/mapper/luks-<uuid>";  # your name from `ls /dev/mapper`
  resumeOffset = "533760";                   # your number from map-swapfile
};
```

`rebuild`, then reboot so the kernel picks up the new `resume=` and `resume_offset=` parameters. Check with `swapon --show` (lists `/swap/swapfile` and `/dev/zram0`) and `cat /proc/cmdline`, then test with `systemctl hibernate`: the laptop powers off, and after the passphrase on the next boot your session comes back as you left it.

With hibernation on, closing the lid **on battery** suspends and then hibernates after 1 hour (`HibernateDelaySec`); on mains it only suspends. If boot sits ~90 s on `a start job is running for dev-mapper-…`, the `resumeDevice` name is wrong: boot the previous generation and correct it. If you recreate or resize the swapfile, read the offset again.

---

## 11. Daily workflow (CachyOS → NixOS)

| CachyOS habit | NixOS equivalent |
|---|---|
| `sudo pacman -Syu` | `update` (= `nh os switch --update`: bumps `flake.lock`, rebuilds) |
| `sudo pacman -S foo` | Add `foo` to `home.packages` in `home.nix` → `rebuild` |
| `flatpak install foo` | Add its app ID to `services.flatpak.packages` in `home.nix` → `rebuild` |
| `:MasonInstall foo` | Enable the server in `lsp_servers.lua` and add its package to `programs.neovim.extraPackages` → `rebuild` |
| Try something once | `nix shell nixpkgs#foo` (gone when you exit) |
| `pacman -Ss foo` | `nix search nixpkgs foo` or search.nixos.org |
| `sudo pacman -R foo` | Delete the line → `rebuild` |
| Broken update | Pick an older generation in the Limine menu, or `sudo nixos-rebuild switch --rollback` |
| `paccache` / orphan cleanup | `cleanup` (also runs weekly automatically) |
| Edit a config in `/etc` | Change the Nix option instead — `/etc` is generated |

### Things that behave differently

- **pip:** `pip install` into the system Python won't work (it's read-only). Use `uv` or `python -m venv .venv` per project. `pip install --user` also works for simple packages.
- **npm -g:** works, installs to `~/.npm-global` (configured for you).
- **base-devel:** the global toolchain is installed so things "just work", but the NixOS-native way is a per-project dev shell that direnv loads when you `cd` in — see below.
- **Neovim LSPs:** come from `programs.neovim.extraPackages` in `home.nix`; your config skips Mason on NixOS (§6). If a plugin downloads its own binary (e.g. blink.cmp's Rust matcher, if you switch it on), `nix-ld` usually lets it run.
- **AppImages:** run directly. Notion no longer needs one (`notion-electron` is packaged).
- **Claude:** the **Claude Code CLI** is installed. The official Claude desktop app's Linux beta ships as a `.deb` for Ubuntu/Debian and isn't in nixpkgs yet — use claude.ai in Brave (installable as a web app) or a community Nix repackaging until it is.

### Dev environments (direnv + nix-direnv)

`programs.direnv` (with its zsh hook) and `nix-direnv` are all the system-side setup needed. Each project then needs three things:

1. **A dev shell** — a `flake.nix` in the project root (or start from a ready-made one: `nix flake init -t github:the-nix-way/dev-templates#python`, `#node`, `#go`…):
   ```nix
   {
     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
     outputs = { nixpkgs, ... }:
       let pkgs = nixpkgs.legacyPackages.x86_64-linux; in {
         devShells.x86_64-linux.default = pkgs.mkShell {
           packages = with pkgs; [ python3 uv nodejs ];
           # env.DATABASE_URL = "postgres://localhost/dev";
         };
       };
   }
   ```
2. **An `.envrc`** next to it containing `use flake` (or `use nix` for an old-style `shell.nix`).
3. **`direnv allow`**, once. direnv refuses to run an `.envrc` until you approve it, and asks again whenever it changes — a deliberate guard against a cloned repo running code when you `cd` into it.

In a git repo, `git add flake.nix` before the first load (flakes only see tracked files) and add `.direnv/` to `.gitignore`. After that, `cd project` loads the tools and `cd ..` unloads them; nix-direnv caches the environment and protects it from garbage collection, so it's instant next time. `direnv reload` forces a rebuild after you edit `flake.nix`.

---

## 12. Next steps once you're happy

- **Secure Boot with Limine:** `sudo sbctl create-keys`, put firmware in Setup Mode, `sudo sbctl enroll-keys --microsoft --firmware-builtin`, then set `boot.loader.limine.secureBoot.enable = true;`.
- **Reproducible disks:** `disko` describes partitions, LUKS and btrfs in Nix, replacing the installer's Partitions screen on your main machines.
- **Main machines:** add `hosts/<machine>/` with its own `configuration.nix` + generated hardware file and another `nixosConfigurations` entry; share common settings by moving them into `modules/`.
