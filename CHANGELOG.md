# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-18

### Added

- Independent per-provider toggles, so non-conflicting VPNs and proxies can run
  together (Tailscale overlay + tunnel, tunnel + system proxy, and so on).
- Conflict-aware starts: tunnel/tunnel, proxy/proxy, and unknown/unknown
  combinations are refused with a notification instead of silently fighting
  over routes, DNS, or the system proxy.
- Automatic discovery of installed VPN/proxy software from a curated binary
  list plus `.desktop` files, with a 30-second cache and a manual rescan.
- Built-in providers: UniVPN, Tailscale, FlClash, Clash Verge, Mihomo,
  sing-box, Hiddify, NekoRay/NekoBox, Mullvad, NordVPN, Proton VPN, WireGuard,
  OpenVPN, OpenConnect, and v2rayA.
- Omarchy bar widget with a popup panel, multi-connection summary, per-row
  conflict hints, and an auto-discovered provider list.
- Optional Omarchy menu rows and a `vpn-switch` CLI for scripts and the menu.
- Omarchy plugin manifest (`io.github.shawnicsc.vpn`) for one-command installs
  through `omarchy plugin add`.
- Installer/uninstaller for the full CLI + bar + menu setup.

### Fixed

- Garbled `0562` menu icon: JSON `\u` escapes take exactly four hexadecimal
  digits, so `\u000f0562` rendered as `U+000F` plus the literal text `0562`.
  The icon now uses the correct surrogate pair for `U+F0562`.
- UniVPN shutdown now waits for the tunnel interface and lets the CSDK clean up
  routing instead of killing the GUI and leaving the tunnel behind.
- FlClash and Clash Verge are detected by their real process names and TUN
  interfaces; system-proxy mode is no longer mistaken for “off”.
