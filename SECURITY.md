# Security

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not
open a public issue for a suspected vulnerability.

Include the affected version, the exact command or UI action, and a minimal
reproduction. Reports are acknowledged as soon as possible.

## Scope

VPN Switch is a local Omarchy bar widget and CLI. It:

- has no network code, telemetry, or remote service;
- executes only the bundled `bin/vpn-switch` script (or `vpn-switch` on `PATH`
  for the full install);
- invokes local VPN clients and standard tools such as `ip`, `pgrep`, `pkill`,
  `tailscale`, and `journalctl`-free process checks;
- does not need elevated privileges and does not modify privilege policy.

The full installer edits `shell.json` and, only with `--with-menu`, the Omarchy
menu extension. It backs up every file it changes and accepts `--dry-run`.
Plugin installs never edit configuration by themselves.

Third-party VPN clients and Omarchy itself are outside this project's security
scope.
