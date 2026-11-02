# =============================================================================
#  HOME MANAGER — your user environment
#  User apps, CLI tools, shell, git, tmux, user services, the links from
#  ~/.config to your existing dotfiles, Neovim + language servers, and
#  declarative Flatpaks. No root needed for anything here.
#  Applied by the same `nh os switch` that applies the system config.
# =============================================================================
{
  config,
  lib,
  pkgs,
  vars,
  inputs,
  ...
}:

let
  # ---------------------------------------------------------------------------
  # DOTFILES
  # Copy these folders from ~/.config on CachyOS into ./dotfiles/ in this repo.
  # Each one gets symlinked to ~/.config/<name>. Because they are *out-of-store*
  # symlinks, editing ~/.config/hypr/hyprland.lua edits the file in this repo
  # directly and takes effect immediately — no rebuild needed (handy while
  # tuning). A missing folder just leaves a dangling link; it does no harm.
  # ---------------------------------------------------------------------------
  dotfiles = "${vars.flakeDir}/dotfiles";

  linkedConfigs = [
    "hypr" # hyprland.lua (+ scripts/ if you keep any)
    "noctalia" # config.toml — bar, launcher, notifications, lock, idle, wallpaper...
    "ghostty"
    "nvim"
    "yazi"
    "btop"
    "starship.toml" # a single file, not a folder — copy ~/.config/starship.toml if you have one
  ];

  linkConfig = name: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${name}";
  };
in
{
  # nix-flatpak's Home Manager module (flake input) — provides the
  # services.flatpak options used in section 10
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  # ===========================================================================
  # 1. IDENTITY
  # ===========================================================================
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # Like system.stateVersion: the Home Manager release you started on.
  # Don't bump it on upgrades. (26.05 also makes HM's Hyprland module default
  # to Lua output — irrelevant here because Hyprland config is your own file.)
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # ===========================================================================
  # 2. PACKAGES
  # ===========================================================================
  home.packages = with pkgs; [
    # ---- Hyprland desktop tools --------------------------------------------
    # (hyprland, xdg-desktop-portal-hyprland and the Noctalia shell come from
    # the system config. Noctalia replaces hyprpaper, hyprshot, waybar, rofi,
    # dunst, hyprlock, hypridle, hyprpolkitagent and cliphist.)
    libnotify # notify-send (Noctalia is the notification daemon that shows them)
    wl-clipboard # wl-copy / wl-paste in scripts and the terminal
    wifitui # TUI Wi-Fi manager (NetworkManager backend)
    networkmanagerapplet # nm-connection-editor (Noctalia's network panel covers day-to-day Wi-Fi)
    pavucontrol # full audio mixer GUI, for what Noctalia's control center doesn't cover
    playerctl # media keys in hyprland.lua (play-pause, next, previous)
    brightnessctl # backlight keys — works without the `video` group via logind

    # ---- Terminal & CLI ----------------------------------------------------
    # (bat, eza and fzf are installed via their programs.* modules in section 6)
    ghostty
    btop
    # neovim itself + LSPs/formatters: see section 9
    ripgrep # Telescope live grep in Neovim
    fd # Telescope find files
    tree-sitter # the tree-sitter CLI (nixpkgs has no separate tree-sitter-cli) for nvim-treesitter
    unzip
    jq

    # ---- Development ("base-devel" equivalent + languages) ----------------
    # On NixOS the idiomatic route is per-project dev shells (see README),
    # but these give you a familiar global toolchain while testing.
    gcc # also used by Neovim: treesitter parsers, telescope-fzf-native, LuaSnip's jsregexp
    gnumake # also used by Neovim: telescope-fzf-native, LuaSnip's jsregexp
    binutils
    pkg-config
    autoconf
    automake
    libtool
    cmake
    patch
    (python3.withPackages (
      ps: with ps; [
        pip
        virtualenv
      ]
    ))
    uv # fast Python project/venv manager — recommended over global pip on NixOS
    nodejs # provides node + npm
    claude-code # Claude Code CLI (see README for the desktop app)

    # ---- Windows compatibility ----------------------------------------------
    wineWow64Packages.stable # 32- and 64-bit Windows apps
    winetricks

    # ---- Desktop applications -----------------------------------------------
    # (OBS is in section 6 via programs.obs-studio)
    mission-center
    gnome-calculator # formerly `gnome.gnome-calculator`; the gnome.* set was removed
    virt-manager # VM GUI; libvirtd itself is in the system config
    libreoffice # latest LibreOffice (use libreoffice-stable for the conservative branch)
    hunspell
    hunspellDicts.en_GB-ise # LibreOffice British English spell-check
    # Brave Origin (packaged in unstable). Falls back to regular Brave if you
    # switch to a nixpkgs branch that doesn't have it yet.
    (pkgs.brave-origin or pkgs.brave)
    proton-vpn # official Proton VPN GTK app (formerly `protonvpn-gui`)
    notion-electron # same anechunaev/notion-electron app as your AppImage, but packaged
    qbittorrent
    vlc
    file-roller # archive backend for Thunar's right-click extract

    # ---- Theming ------------------------------------------------------------
    adwaita-icon-theme
  ];

  # ===========================================================================
  # 3. DOTFILE LINKS (~/.config/<name> -> ~/nixos-config/dotfiles/<name>)
  # ===========================================================================
  xdg.configFile = lib.genAttrs linkedConfigs linkConfig;

  # ===========================================================================
  # 4. ENVIRONMENT
  # ===========================================================================
  # (EDITOR/VISUAL = nvim are set by programs.neovim.defaultEditor)
  home.sessionVariables = {
    TERMINAL = "ghostty";
  };

  # Global npm installs (`npm i -g`) go to ~/.npm-global, because /nix/store
  # is read-only. ~/.local/bin is where `pip install --user` / uv tools go.
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm-global
  '';
  home.sessionPath = [
    "$HOME/bin" # from your old .zshrc
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];

  # ===========================================================================
  # 5. SHELL — zsh
  # ===========================================================================
  # Replaces oh-my-zsh: your plugins (zsh-autosuggestions, zsh-syntax-highlighting,
  # git) are loaded directly, and the oh-my-zsh defaults you'd notice missing
  # (completion menu, key bindings, history and directory options) are set
  # explicitly below. The prompt is starship (section 6).
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true; # was the zsh-autosuggestions plugin
    syntaxHighlighting.enable = true; # was the zsh-syntax-highlighting plugin
    defaultKeymap = "emacs"; # oh-my-zsh's default (bindkey -e)
    autocd = true; # type a directory name to cd into it (oh-my-zsh default)

    history = {
      size = 50000;
      save = 50000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreSpace = true; # a command starting with a space isn't saved
      expireDuplicatesFirst = true;
      extended = true; # save timestamps
      share = true;
    };

    # Other oh-my-zsh defaults
    setOptions = [
      "AUTO_PUSHD" # cd pushes onto the directory stack (`cd -<Tab>` to pick one)
      "PUSHD_IGNORE_DUPS"
      "PUSHD_MINUS"
      "HIST_VERIFY" # show !! / !$ expansions before running them
      "INTERACTIVE_COMMENTS" # allow # comments on the command line
      "LONG_LIST_JOBS"
      "COMPLETE_IN_WORD"
      "ALWAYS_TO_END"
      "AUTO_MENU"
    ];

    # oh-my-zsh's git plugin on its own (~200 aliases: gst, gco, gcmsg, gp,
    # glog...), loaded straight from nixpkgs' copy without the framework
    plugins = [
      {
        name = "omz-git";
        src = "${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/git";
        file = "git.plugin.zsh";
      }
    ];

    shellAliases = {
      # NixOS workflow
      rebuild = "nh os switch"; # apply config changes
      update = "nh os switch --update"; # update flake inputs + apply (≈ pacman -Syu)
      rebuild-test = "nh os test"; # apply until next reboot only
      cleanup = "nh clean all --keep 5";

      # Your eza aliases (the shared flags — icons, colour, directories first —
      # are set once in programs.eza in section 6)
      ls = "eza -a";
      ll = "eza -alh --total-size";
      lt = "eza -aT";

      cat = "bat --paging=never"; # plain `bat` still pages long files
      md = "mkdir -p"; # oh-my-zsh
      "-" = "cd -"; # oh-my-zsh: `-` jumps back to the previous directory
      # vi / vim → nvim come from section 9 (viAlias / vimAlias)
    };

    # oh-my-zsh: `cd ...` = cd ../.., `cd ....` = cd ../../..
    shellGlobalAliases = {
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
    };

    initContent = lib.mkMerge [
      # General configuration (after compinit and plugins, before aliases)
      ''
        # ---- Completion (oh-my-zsh defaults) ----------------------------------
        zmodload -i zsh/complist
        unsetopt menu_complete flowcontrol
        zstyle ':completion:*:*:*:*:*' menu select
        # case-insensitive, then partial-word and substring matching
        zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*' special-dirs true
        zstyle ':completion:*' list-colors ""
        zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
        zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
        zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
        zstyle ':completion:*' use-cache yes
        zstyle ':completion:*' cache-path "${config.xdg.cacheHome}/zsh/zcompcache"

        # ---- Key bindings -----------------------------------------------------
        # Word-wise movement and deletion stop at / . - _ (oh-my-zsh's WORDCHARS)
        WORDCHARS=""
        # Your bindings
        bindkey '^H' backward-kill-word          # Ctrl+Backspace
        bindkey '^[[8;6u' kill-whole-line        # Ctrl+Shift+Backspace
        # Up/Down search history for lines starting with what you've typed
        autoload -U up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        bindkey '^[[A' up-line-or-beginning-search
        bindkey '^[OA' up-line-or-beginning-search
        bindkey '^[[B' down-line-or-beginning-search
        bindkey '^[OB' down-line-or-beginning-search
        # Home / End / Delete / Ctrl+Delete / Ctrl+←→ / Shift+Tab
        bindkey '^[[H' beginning-of-line
        bindkey '^[OH' beginning-of-line
        bindkey '^[[F' end-of-line
        bindkey '^[OF' end-of-line
        bindkey '^[[3~' delete-char
        bindkey '^[[3;5~' kill-word
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word
        bindkey '^[[Z' reverse-menu-complete
        # Ctrl+X Ctrl+E edits the current command in $EDITOR (nvim)
        autoload -U edit-command-line
        zle -N edit-command-line
        bindkey '^X^E' edit-command-line

        # ---- Helpers the oh-my-zsh git plugin expects --------------------------
        # (normally provided by oh-my-zsh's lib/git.zsh; used by ggpush, ggpull...)
        __git_prompt_git() { GIT_OPTIONAL_LOCKS=0 command git "$@"; }
        git_current_branch() {
          local ref
          ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2>/dev/null)
          local ret=$?
          if [[ $ret != 0 ]]; then
            [[ $ret == 128 ]] && return
            ref=$(__git_prompt_git rev-parse --short HEAD 2>/dev/null) || return
          fi
          echo ''${ref#refs/heads/}
        }
      ''

      # Last: anything that must see the aliases above
      (lib.mkAfter ''
        # Your cd: change directory, then list it (uses the eza `ls` alias)
        cd() {
          builtin cd "$@" && ls
        }

        # Extra personal config (functions, local tweaks) — optional file
        [[ -f "${dotfiles}/zsh/personal.zsh" ]] && source "${dotfiles}/zsh/personal.zsh"
      '')
    ];
  };

  # ===========================================================================
  # 6. CLI PROGRAMS CONFIGURED BY HOME MANAGER
  # ===========================================================================
  programs.git = {
    enable = true;
    settings = {
      user.name = vars.fullName;
      user.email = vars.email;
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0; # no Esc delay in Neovim
    historyLimit = 50000;
    terminal = "tmux-256color";
    # extraConfig = '' ... paste your existing tmux.conf here ... '';
  };

  # Yazi: Home Manager adds the `y` shell wrapper (cd to the dir you quit in).
  # Its config files come from dotfiles/yazi, so no settings are set here.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  # zoxide (`z dir`) — also used by Yazi's jump plugin
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # fzf: installs it and adds the zsh keybindings —
  # Ctrl-R fuzzy history, Ctrl-T insert file path, Alt-C cd into directory
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git"; # respect .gitignore, include dotfiles
    fileWidget.command = "fd --type f --hidden --exclude .git"; # Ctrl-T
    changeDirWidget.command = "fd --type d --hidden --exclude .git"; # Alt-C
  };

  # bat: `cat` with syntax highlighting and git markers
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      style = "numbers,changes,header";
    };
  };

  # eza: modern `ls`. These options become an `eza` alias, so they apply to
  # your ls / ll / lt aliases (section 5) and to plain `eza` alike.
  # The zsh integration also adds la (eza -a) and lla (eza -la).
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "always"; # from your .zshrc (uses the Nerd Fonts from the system config)
    colors = "always"; # from your .zshrc
    git = true; # git status column in long listings (ll)
    extraOptions = [ "--group-directories-first" ]; # from your .zshrc
  };

  # Starship prompt (replaces `eval "$(starship init zsh)"`). Its config is
  # your own ~/.config/starship.toml, linked from dotfiles/ (section 3).
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # direnv + nix-direnv: entering a folder with an .envrc loads its dev
  # environment, leaving unloads it. nix-direnv caches `use flake` / `use nix`
  # environments and protects them from garbage collection, so re-entering is
  # instant. Per project: `echo "use flake" > .envrc && direnv allow` (README §11).
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true; # skip the long "+VAR -VAR" list on every cd
  };

  # OBS Studio. The virtual-camera kernel module is set up in the system config.
  programs.obs-studio.enable = true;

  # ===========================================================================
  # 7. USER SERVICES (systemd --user, started with the UWSM graphical session)
  # Remove the matching exec lines from hyprland.lua so they don't start twice.
  # The Noctalia shell's own service is defined in the system config
  # (programs.noctalia.systemd). It also provides the polkit agent and
  # clipboard history, which hyprpolkitagent and cliphist used to.
  # ===========================================================================
  services.network-manager-applet.enable = true; # nm-applet tray icon (moved from system config)
  # Makes nm-applet use the StatusNotifier tray protocol (--indicator), the
  # kind Noctalia's tray shows. (Despite the name, nothing X11-specific.)
  xsession.preferStatusNotifierItems = true;

  # Tracks the most recently active media player, so `playerctl play-pause`
  # (media keys in hyprland.lua) controls whatever you used last
  services.playerctld.enable = true;

  services.udiskie = {
    enable = true; # automount USB drives
    automount = true;
    notify = true;
    tray = "never"; # set "auto" if you want its tray icon in Noctalia's bar
  };

  # ===========================================================================
  # 8. LOOK & FEEL
  # ===========================================================================
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true; # also sets HYPRCURSOR_THEME/SIZE for Hyprland
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "advaita-dark";
  };

  dconf.settings = {
    # Dark mode for GTK4/libadwaita apps and the portal (Brave, Electron apps)
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";

    # virt-manager connects to the system libvirt daemon automatically
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

  # ===========================================================================
  # 9. NEOVIM + LANGUAGE SERVERS
  # Your config (dotfiles/nvim, linked in section 3) runs on NixOS and other
  # distros. On NixOS it skips Mason by itself (it checks for /etc/NIXOS), so
  # the language servers must come from here: the packages below go on
  # Neovim's own PATH (via its wrapper), visible to nvim and its :terminal.
  #
  # Rule: every server enabled in lua/config/lsp_servers.lua needs its package
  # here. The list below mirrors that file — enabled there = active here,
  # commented there = commented here — so enabling a server means
  # uncommenting it in both places, then `rebuild`.
  #
  # Plugins are NOT managed here: your config installs them with vim.pack
  # (Neovim 0.12's built-in plugin manager). On first launch it asks to
  # install them (answer Always) and writes nvim-pack-lock.json into
  # dotfiles/nvim; commit that file so every machine gets the same versions.
  # The tools it builds plugins with are in section 2 (git, gcc, gnumake,
  # tree-sitter, ripgrep, fd); curl and tar come with NixOS itself.
  # ===========================================================================
  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets EDITOR and VISUAL to nvim
    viAlias = true;
    vimAlias = true;

    # Home Manager generates a small init.lua (it switches off the Python,
    # Node, Ruby and Perl providers, which your config doesn't use).
    # Sideloading passes it via the wrapper instead of writing
    # ~/.config/nvim/init.lua — which would overwrite your linked config.
    sideloadInitLua = true;

    extraPackages = with pkgs; [
      # ---- Enabled in lsp_servers.lua -------------------------  lspconfig name
      clang-tools # clangd (also clang-format)
      basedpyright # basedpyright
      rust-analyzer # rust_analyzer — needs cargo/rustc from the project's
      #   dev shell (direnv, README §11) or add them to home.packages
      marksman # marksman
      terraform-ls # terraformls
      stylua # stylua — runs as a server (`stylua --lsp`) and formats Lua
      lua-language-server # lua_ls

      # ---- Commented out in lsp_servers.lua — uncomment both together ----
      # bash-language-server # bashls
      # shellcheck # bashls runs it for its diagnostics
      # yaml-language-server # yamlls
      # vscode-langservers-extracted # jsonls (also provides html, cssls, eslint)
      # (sqlls: its server, sql-language-server, isn't packaged in nixpkgs.
      #  Use the `sqls` server instead — package `sqls`, key `sqls = {}`.)

      # ---- Not in lsp_servers.lua yet — add the server there to use one ----
      # nixd # nixd — for editing this repo
      # ruff # ruff (Python lint + format)
      # typescript-language-server # ts_ls
      # taplo # taplo (TOML)
      # dockerfile-language-server # dockerls
      # docker-compose-language-service # docker_compose_language_service
      # ansible-language-server # ansiblels
      # helm-ls # helm_ls
      # gopls # gopls (Go)
      # Formatters/linters for conform.nvim's formatters_by_ft (formatting.lua):
      # nixfmt prettierd shfmt hadolint

      # ---- Plugin builds ---------------------------------------------------
      tree-sitter # CLI nvim-treesitter compiles parsers with (needs 0.26.1+)
    ];
  };

  # ===========================================================================
  # 10. DECLARATIVE FLATPAKS (nix-flatpak)
  # Listed apps are installed into your *user* Flatpak installation on every
  # rebuild; delete a line and it is uninstalled. The Flatpak runtime itself
  # is enabled in the system config (services.flatpak.enable).
  #
  # Find app IDs:  flatpak search <name>   or the URL on flathub.org
  # Installs run in a systemd user service after activation, so a rebuild
  # returns before downloads finish. Watch them with:
  #   journalctl --user -fu flatpak-managed-install
  # ===========================================================================
  services.flatpak = {
    # Flathub is added automatically as the default remote.

    packages = [
      "com.github.tchx84.Flatseal" # GUI for reviewing/changing Flatpak permissions
      # Add apps you want sandboxed or that aren't in nixpkgs, e.g.:
      # "com.spotify.Client"
      # "com.discordapp.Discord"
      # "md.obsidian.Obsidian"
      # Pin to a specific commit:
      # { appId = "org.example.App"; origin = "flathub"; commit = "<hash>"; }
    ];

    # Fully declarative: Flatpaks/remotes in your user installation that are
    # NOT listed above are removed on rebuild. Set false while experimenting
    # if you want to `flatpak install` things by hand and keep them.
    uninstallUnmanaged = true;

    # Update Flatpaks weekly (and once on each activation)
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    # Permission/environment overrides, applied to all apps ("global") or one app ID.
    # These replace any override files in ~/.local/share/flatpak/overrides.
    overrides.settings = {
      global = {
        Environment = {
          # Let sandboxed apps see the host cursor theme (Bibata) on Wayland
          XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
          # Dark GTK theme inside the sandbox, matching the desktop
          GTK_THEME = "Adwaita:dark";
        };
      };
      # "com.example.App".Context.sockets = [ "wayland" "!x11" ];
    };
  };
}
