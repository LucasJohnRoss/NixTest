# =============================================================================
#  SYSTEM CONFIGURATION — test laptop
#  Everything that needs root: boot, kernel, hardware, services, users,
#  system-wide programs. Per-user apps and dotfiles live in home/home.nix.
#  Apply changes with:  nh os switch   (or: sudo nixos-rebuild switch --flake ~/nixos-config)
# =============================================================================
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:

let
  # ---------------------------------------------------------------------------
  # HIBERNATION SWITCH
  # Leave `enable = false` until the swapfile exists and you have its offset
  # (README §10 "Enable hibernation"). Enabling it with wrong values would make
  # the initrd wait for a resume device that isn't there.
  # ---------------------------------------------------------------------------
  hibernation = {
    enable = false;
    swapfile = "/swap/swapfile";
    # The block device that holds the btrfs filesystem. With LUKS this is the
    # *unlocked* mapper device. The GUI installer names it luks-<uuid>:
    # copy the name from `ls /dev/mapper`.
    resumeDevice = "/dev/mapper/luks-CHANGEME";
    # Output of: sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
    resumeOffset = "CHANGEME";
  };

  # ---------------------------------------------------------------------------
  # AUTOLOGIN SWITCH
  # true: boot straight into Hyprland after the LUKS passphrase (the disk
  # passphrase is then the only password at boot). The greeter still appears
  # after you log out. See section 9 for the keyring caveat.
  # ---------------------------------------------------------------------------
  autoLogin = true;
in
{
  # ===========================================================================
  # 1. IMPORTS
  # ===========================================================================
  imports = [
    # Generated on the laptop by `nixos-generate-config`: disks, LUKS device,
    # btrfs subvolumes, kernel modules, CPU microcode. Never hand-write this.
    ./hardware-configuration.nix
  ];

  # ===========================================================================
  # 2. NIX ITSELF
  # ===========================================================================
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true; # hard-link identical files in /nix/store
    trusted-users = [
      "root"
    ];
  };

  # Brave, Claude Code, etc. are unfree licences
  nixpkgs.config.allowUnfree = true;

  # `nh` — a friendlier front-end for nixos-rebuild that shows a package diff
  # before switching, plus automatic garbage collection of old generations.
  programs.nh = {
    enable = true;
    flake = vars.flakeDir;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  # Lets pre-built, dynamically linked Linux binaries run (npm packages with
  # native binaries, pip wheels, VS Code remote servers, downloaded CLIs...).
  # Without it they fail with "No such file or directory".
  programs.nix-ld = {
    enable = true;
    # Libraries those binaries can find. This list is ADDED to nix-ld's
    # built-in set, which is always included:
    #   zlib zstd stdenv.cc.cc (libstdc++) curl openssl attr libssh bzip2
    #   libxml2 acl libsodium util-linux xz systemd
    # When a binary fails with "error while loading shared libraries: libX.so",
    # find the package that provides libX.so on search.nixos.org (or with
    # `nix-locate libX.so`), add it here and rebuild.
    libraries = with pkgs; [
      # Common extras — uncomment what you need:
      # glib # libglib/libgobject — many GUI and Electron binaries
      # libGL # OpenGL
      # libxkbcommon # keyboard handling in GUI binaries
      # libx11 # X11 apps under XWayland
      # nss # Chromium/Electron-based binaries
      # nspr
      # alsa-lib # audio
      # fontconfig
      # freetype
      # dbus
      # icu # .NET binaries
      # libffi # some Python wheels
    ];
  };

  # ===========================================================================
  # 3. BOOT: Limine, kernel, Plymouth, quiet boot
  # ===========================================================================
  boot = {
    loader = {
      limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 10; # how many old generations appear in the boot menu
        # Old laptop with legacy BIOS (no UEFI)? Use these instead of efiSupport:
        # efiSupport = false;
        # biosSupport = true;
        # biosDevice = "/dev/sda";
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    # Latest mainline kernel (CachyOS ships a patched one; mainline is the
    # closest built-in equivalent). Remove this line for the default LTS kernel.
    kernelPackages = pkgs.linuxPackages_latest;

    # Note: the initrd is always systemd-based now (it handles LUKS unlock,
    # Plymouth and resume) — the old scripted initrd has been removed.
    # Load the GPU driver early so Plymouth shows the LUKS prompt at native
    # resolution. Uncomment the one matching the laptop:
    # initrd.kernelModules = [ "i915" ];   # Intel
    # initrd.kernelModules = [ "amdgpu" ]; # AMD

    # Boot splash
    plymouth.enable = true;

    # Hide kernel/systemd text so the splash isn't interrupted
    # (the Plymouth module adds "splash" itself)
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ]
    ++ lib.optional hibernation.enable "resume_offset=${hibernation.resumeOffset}";

    # Where the kernel looks for a hibernation image on boot
    resumeDevice = lib.mkIf hibernation.enable hibernation.resumeDevice;

    supportedFilesystems = [ "btrfs" ];
  };

  # ===========================================================================
  # 4. FILESYSTEM, SWAP & HIBERNATION
  # ===========================================================================
  # Mount options for the btrfs layout the GUI installer creates (top level at /,
  # plus `home` and `nix` subvolumes).
  # These lists merge with the `subvol=` options in hardware-configuration.nix.
  # If you used a different subvolume layout, keep only the mount points you have.
  fileSystems = {
    "/".options = [
      "compress=zstd"
      "noatime"
    ];
    "/home".options = [
      "compress=zstd"
      "noatime"
    ];
    "/nix".options = [
      "compress=zstd"
      "noatime"
    ];
  };

  # Monthly integrity check of btrfs data/metadata checksums
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Compressed RAM swap (CachyOS default). Used first for everyday swapping;
  # hibernation skips zram and uses the disk swapfile below.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Disk swapfile on its own btrfs subvolume — required for hibernation.
  swapDevices = lib.mkIf hibernation.enable [ { device = hibernation.swapfile; } ];

  # ===========================================================================
  # 5. POWER, LID & SLEEP (laptop)
  # ===========================================================================
  # power-profiles-daemon and upower also feed Noctalia's power-profile and
  # battery widgets (section 9)
  services.power-profiles-daemon.enable = true; # balanced / power-saver / performance
  services.upower.enable = true; # battery info for Noctalia's bar
  services.fwupd.enable = true; # firmware updates: fwupdmgr refresh && fwupdmgr update

  # logind does the actual suspending on lid close. Noctalia locks the screen
  # first by itself (it holds a logind sleep-delay inhibitor and locks on
  # PrepareForSleep — `lock_before_suspend` in dotfiles/noctalia/config.toml),
  # so hyprland.lua no longer needs a lid-switch bind.
  services.logind.settings.Login = {
    # Closing the lid on battery: suspend, then hibernate after HibernateDelaySec
    HandleLidSwitch = if hibernation.enable then "suspend-then-hibernate" else "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "1h";

  # ===========================================================================
  # 6. NETWORKING & DNS (Quad9)
  # ===========================================================================
  networking = {
    hostName = vars.hostname;

    networkmanager = {
      enable = true; # used by Noctalia's network panel, nm-connection editor, Proton VPM
      dns = "systemd-resolved"; # hand DNS to resolved (below)
    };

    # Quad9 (9.9.9.9 + secondary + IPv6). The "#dns.quad9.net" suffix is the
    # TLS hostname used to verify DNS-over-TLS.
    nameservers = [
      "9.9.9.9#dns.quad9.net"
      "149.112.112.112#dns.quad9.net"
      "2620:fe::fe#dns.quad9.net"
      "2620:fe::9#dns.quad9.net"
    ];

    firewall = {
      enable = true;
      # Proton VPN (WireGuard) breaks with strict reverse-path filtering
      checkReversePath = "loose";
      # allowedTCPPorts = [ ];  # e.g. a fixed qBittorrent listening port
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      # DNS = networking.nameservers (the module's default) — i.e. Quad9.
      # "~." makes Quad9 the preferred resolver for ALL domains, so the router's
      # DHCP-supplied DNS isn't used instead.
      Domains = [ "~." ];
      # Encrypt to Quad9 when possible. "true" enforces it but breaks hotel /
      # café captive portals, so opportunistic is the pragmatic default.
      DNSOverTLS = "opportunistic";
      # Don't fall back to systemd's built-in Cloudflare/Google list
      FallbackDNS = [
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
    };
  };

  # ===========================================================================
  # 7. LOCALE, TIME, KEYBOARD
  # ===========================================================================
  time.timeZone = vars.timezone;
  i18n.defaultLocale = vars.locale;
  services.xserver.xkb.layout = vars.keyboardLayout; # system XKB layout (no X server is installed)
  console.useXkbConfig = true; # TTY + LUKS prompt use the same layout
  # (the login screen's layout is set in section 9: noctalia-greeter `keyboard.layout`)

  # ===========================================================================
  # 8. HARDWARE: graphics, audio, Bluetooth, backlight
  # ===========================================================================
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed by Wine and 32-bit apps
    # Video acceleration — uncomment for the laptop's GPU:
    # extraPackages = with pkgs; [ intel-media-driver ];  # Intel Broadwell+ (vaapi)
    # extraPackages = with pkgs; [ intel-vaapi-driver ];  # older Intel
  };
  # NVIDIA laptop? See https://wiki.nixos.org/wiki/NVIDIA

  # PipeWire replaces PulseAudio/JACK (same as CachyOS)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ===========================================================================
  # 9. LOGIN SCREEN, HYPRLAND, NOCTALIA SHELL & DESKTOP PLUMBING
  # ===========================================================================
  # ---- Login screen: Noctalia Greeter (replaces SDDM) -----------------------
  # A greetd greeter styled like Noctalia. This module turns on greetd (which
  # creates the `greeter` system user), AccountsService (user avatars) and
  # polkit. greetd's PAM stack includes `login`, so your login password still
  # unlocks the GNOME keyring below.
  services.displayManager.noctalia-greeter = {
    enable = true;

    # Written to /var/lib/noctalia-greeter/greeter.toml on every boot/switch.
    # Everything here wins over what Noctalia's "Sync" copies across
    # (Settings → Security → Noctalia Greeter → Sync Now: wallpaper, colours).
    settings = {
      # The session's Name= as shown in the picker (from hyprland-uwsm.desktop)
      session.default = "Hyprland (uwsm-managed)";
      user.default = vars.username; # open straight on your password field
      keyboard.layout = vars.keyboardLayout; # UK layout for the password, same as the TTY
    };

    # Same cursor as your session (home.nix section 8)
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };

    # Lets you run Noctalia's greeter Sync without an admin password prompt.
    # The sync helper is appearance-only (wallpaper, palette, monitor layout)
    # and cannot change session commands. Remove the line to require
    # authentication for every sync.
    passwordlessSyncUsers = [ vars.username ];
  };
  # Not read by the greeter (it uses session.default above), but NixOS checks
  # the name exists — a useful guard against a typo'd session name.
  services.displayManager.defaultSession = "hyprland-uwsm";
  services.greetd.settings.initial_session = lib.mkIf autoLogin {
    user = vars.username;
    command = "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
  };

  programs.hyprland = {
    enable = true;
    # UWSM wraps Hyprland in a proper systemd user session: graphical-session
    # target, XDG autostart, clean logout. Shown as "Hyprland (UWSM)" in the greeter.
    withUWSM = true;
    xwayland.enable = true;
  };
  # The Hyprland module already adds xdg-desktop-portal-hyprland.
  # The GTK portal adds file pickers / settings for GTK & Electron apps.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # ---- Noctalia shell --------------------------------------------------------
  # One program replacing Waybar (bar + tray), Rofi (launcher), Dunst
  # (notifications), hyprpaper/wallpaper tools, hyprlock (lock screen),
  # hypridle (idle actions), hyprpolkitagent (polkit prompts), hyprshot
  # (screenshots) and cliphist (clipboard history).
  # The package comes straight from nixpkgs (Hydra-cached, no extra flake input).
  # Its settings are your own TOML in dotfiles/noctalia/ (linked by home.nix),
  # so they work unchanged on non-NixOS machines.
  programs.noctalia = {
    enable = true;
    # Run it as a systemd user service tied to graphical-session.target, which
    # UWSM starts with Hyprland: restarted if it crashes, logs in
    # `journalctl --user -u noctalia`, and lets Noctalia launch apps as their
    # own systemd units (`launch_apps_as_systemd_services` in config.toml).
    # Because of this, hyprland.lua does NOT exec noctalia.
    systemd.enable = true;
    # recommendedServices.enable would turn on NetworkManager, Bluetooth,
    # UPower and power-profiles-daemon — all already enabled explicitly above.
  };
  # The lock screen authenticates against the existing `login` PAM service,
  # so (unlike hyprlock) it needs no PAM entry of its own.

  # Electron/Chromium apps (Brave, Notion, Claude, Obsidian...) use native Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Noctalia registers its own polkit agent (`polkit_agent = true` in config.toml)
  security.polkit.enable = true;
  programs.dconf.enable = true; # GTK settings storage (also used by virt-manager)

  # Secret Service keyring — Proton VPN and Brave store credentials here.
  # This module adds the keyring to the `login` PAM service, which greetd
  # includes, so logging in through the greeter unlocks it automatically.
  # (Autologin can't — see the autologin block above.)
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true; # GUI to inspect the keyring

  # ===========================================================================
  # 10. FILES: Thunar, automounting, thumbnails, AppImages, Flatpak
  # ===========================================================================
  programs.thunar = {
    enable = true;
    plugins = [
      (pkgs.thunar-archive-plugin or pkgs.xfce.thunar-archive-plugin) # right-click extract/compress
      (pkgs.thunar-volman or pkgs.xfce.thunar-volman) # removable media handling
    ];
  };
  programs.xfconf.enable = true; # lets Thunar save its preferences outside XFCE
  services.gvfs.enable = true; # trash, network shares, MTP phones in Thunar
  services.tumbler.enable = true; # thumbnails in Thunar
  services.udisks2.enable = true; # backend for udiskie (automount)

  # Run AppImages directly (./Notion.AppImage), like on Arch
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Flatpak runtime. Which apps are installed (and the Flathub remote) is
  # declared per-user in home/home.nix (section 10) via nix-flatpak.
  services.flatpak.enable = true;

  # ===========================================================================
  # 11. VIRTUALISATION: Docker, KVM/QEMU/libvirt, virt-manager
  # ===========================================================================
  virtualisation.docker = {
    enable = true;
    # Start on first use (socket activation) instead of at boot — faster boot.
    enableOnBoot = false;
    autoPrune.enable = true; # weekly `docker system prune`
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm; # host-arch QEMU only (smaller than full qemu)
      runAsRoot = false;
      swtpm.enable = true; # virtual TPM (Windows 11 guests)
      # UEFI (OVMF) firmware images are included by default.
    };
  };
  virtualisation.spiceUSBRedirection.enable = true; # pass USB devices into VMs
  # virt-manager (the GUI) is installed by Home Manager — home.nix section 2

  # ===========================================================================
  # 12. SHELL & USER ACCOUNT
  # ===========================================================================
  # Must be enabled system-wide for zsh to be a valid login shell;
  # your actual zsh config is in home.nix.
  programs.zsh.enable = true;
  # Home Manager runs compinit itself; skipping the system-wide one avoids
  # running it twice (a slower shell start)
  programs.zsh.enableGlobalCompInit = false;
  # Expose completions shipped by system packages (e.g. systemctl, nix) to zsh
  environment.pathsToLink = [ "/share/zsh" ];

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # manage Wi-Fi without sudo
      "docker" # docker without sudo (NB: root-equivalent)
      "libvirtd"
      "kvm"
    ];
    # Password: the one set in the GUI installer carries over; change it any time with `passwd`.
  };

  # ===========================================================================
  # 13. SYSTEM PACKAGES & PROGRAMS
  # Only what root needs, or what must be set up system-wide (kernel modules,
  # D-Bus services, PAM). Every application is in home.nix.
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # Rescue/admin tools — available to root and in a TTY even if your user
    # environment is broken
    curl
    wget
    git
    vim
    pciutils # lspci
    usbutils # lsusb
    btrfs-progs
    cryptsetup
    sbctl # Secure Boot keys for Limine later (README → next steps)
  ];

  # OBS virtual camera: only the v4l2loopback kernel module is set up here
  # (`package = null` installs no OBS). OBS itself comes from Home Manager.
  programs.obs-studio = {
    enable = true;
    package = null;
    enableVirtualCamera = true;
  };

  # ===========================================================================
  # 14. FONTS
  # ===========================================================================
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome # general-purpose icon font (Noctalia ships its own icons)
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  # ===========================================================================
  # 15. STATE VERSION
  # The NixOS release this machine was FIRST INSTALLED with. It is not the
  # version you're running — never bump it on upgrades. Use the value that
  # nixos-generate-config wrote into its generated configuration.nix.
  # ===========================================================================
  system.stateVersion = "26.05";
}
