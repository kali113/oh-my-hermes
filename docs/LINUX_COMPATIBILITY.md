# Linux Compatibility

`oh-hermes` is Arch-first, but the control layer is intentionally Linux-aware instead of Arch-only.

## Commands

```bash
oh-hermes linux status
oh-hermes linux doctor --json
oh-hermes linux deps
oh-hermes linux service-check --json
oh-hermes desktop doctor --json
```

## What Is Checked

- distro and package manager
- user `systemd` reachability
- Wayland, X11, headless, SSH, and WSL signals
- desktop environment hints
- `bash`, `git`, `curl`, `jq`, `python3`, `node`, `npm`, `uv`, `systemctl`, `notify-send`, `xdg-open`, and `hermes`
- FUSE and AppImage risk for Electron-style desktop packaging
- notification and browser helpers
- official Hermes Desktop command availability

## Support Boundary

Arch Linux is the primary target. Other distros get detection, dependency guidance, and graceful degradation.

Official Hermes Desktop is wrapped through `hermes desktop`. Legacy third-party desktop sources are not used unless `OH_HERMES_DESKTOP_LEGACY_SOURCE=1` is set.

Linux GUI computer-control is not assumed by `oh-hermes`; this layer verifies Desktop app/runtime compatibility and leaves computer-use capability boundaries to upstream Hermes.
