# =============================================================================
#  PLACEHOLDER — REPLACE THIS FILE
#
#  This file must come from the laptop itself, because it describes that
#  exact machine: disk UUIDs, the LUKS device, btrfs subvolumes, kernel
#  modules for its storage controller, and CPU microcode.
#
#  The GUI installer generates it at /etc/nixos/hardware-configuration.nix.
#  After the first boot (README §8.4, step 3):
#    cp /etc/nixos/hardware-configuration.nix ~/nixos-config/hosts/test-laptop/
#
#  Until it is replaced, evaluating the flake stops with the message below,
#  so you can't accidentally install a system that has no disks defined.
# =============================================================================
{ ... }:
throw ''
  hosts/test-laptop/hardware-configuration.nix is still the placeholder.
  Copy the real one from /etc/nixos/hardware-configuration.nix (see README §8.4).
''
