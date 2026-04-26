# Milieu Environment - File Reference Index

This document provides a comprehensive explanation of every tracked file in the `milieu` project. This is targeted towards LLM agents to quickly understand the purpose, structure, and behavior of the repository.

## Working Note

Always update this file as you work so you can reference it to make doing stuff latter easier, even if you are actually just finding stuff that wasn't documented correctly before

## Root Scripts

- **`build.sh`**
  The main build pipeline script. Compiles musl-cross toolchain, toybox, busybox, mksh, dash, sbase, ubase, coreutils, util-linux, zlib, mandoc, binutils, btop, and more from source. Downloads Go, Rust, and Python uv toolchains. Also installs: `nix-portable` as `bin/nix` (store → `$ENV_ROOT/.nix-portable`); `podman-static` ELF binaries (only `usr/local/bin/` and `usr/local/lib/podman/`, never `share/`) into `libexec/podman-static/bin/`; `distrobox` into `bin/`. Generates `etc/containers/containers.conf` from the committed template `etc/containers/containers.conf.in` via `sed`.

- **`install-links.sh`**
  Handles the creation of relative symlinks for all utilities inside the `bin/` directory. It establishes a priority hierarchy (e.g., `mksh` > `dash` >  `coreutils` > `toybox` > `busybox` > `sbase` > `ubase` >`util-linux` > `zlib` > `mandoc` > `binutils`) to resolve naming conflicts, ensuring that standard milieu tools are correctly mapped.

- **`package.sh`**
  A utility script to bundle the compiled and configured `milieu` environment into portable tarballs for distribution. It generates both a binary bundle containing just the executable environment and a source bundle for rebuilding.
  > **Note regarding packaging and `/usr`:** The `usr` directory is implemented as a symlink pointing back to the root of the environment (`.`). This means that anything you explicitly place into `usr/` actually just gets dumped into the project root directory. Because `package.sh` targets specific directories (`bin`, `etc`, `lib`, `libexec`, `share`, `usr`), files inadvertently placed in the root directory via the `usr/` symlink will **not** be included in the binary package. Always use `libexec/` or `lib/` to store standalone applications and toolchains.

## Launchers (Entrypoints)

- **`milieu-sh`**
  Enters the `milieu` environment with an **isolated** `PATH`. This is a strict sandbox where only the locally compiled tools in `bin/` are accessible, completely obscuring system tools. Drops the user into `mksh`.

- **`milieu-sh-sys`**
  Enters the `milieu` environment with `bin/` **prepended** to the `PATH`. This provides a hybrid environment where milieu tools have precedence, but system-wide tools remain available as fallbacks. Drops the user into `mksh`.

- **`milieu-sh-overlay`**
  Overlays `milieu` tools onto the user's *existing* shell rather than forcing `mksh`. It retains the user's current `$SHELL` but prepends milieu's `bin/` directory to the `PATH`.

## Configurations (`configs/` and `etc/`)

- **`configs/busybox.config`**
  The build configuration file for compiling `busybox`. Dictates the selection of applets to build and ensures static linking is enabled.

- **`configs/toybox.config`**
  The build configuration file for compiling `toybox`. Guarantees statically linked executables and enforces required configurations (like `vi`).

- **`etc/mkshrc`**
  The interactive shell configuration file used by `mksh`. Sets up command history tracking, common aliases (`l`, `ll`, `la`), and most importantly, defines the custom dynamic `_milieu_prompt` function to visually indicate user privileges, exit codes, and the current working directory.

- **`etc/profile`**
  The environment initialization profile. Sets `HOME`, `PATH`, `PAGER`, and all toolchain roots (Go, Rust, uv). Sets XDG base dirs (`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR`) all pointing into `$ENV_ROOT`. Sets `CONTAINERS_CONF` to the build-generated `etc/containers/containers.conf`, `CONTAINERS_REGISTRIES_CONF`, `DBX_CONTAINER_MANAGER=podman`, `DBX_CONTAINER_HOME_PREFIX`, and `NP_LOCATION`. No config generation happens here.

- **`etc/containers/containers.conf.in`**
  Committed TOML template for podman. Contains `@MILIEU_DIR@` placeholder. `build.sh` runs `sed` to produce `etc/containers/containers.conf` with real absolute paths. **Do not edit `containers.conf` directly — edit the `.in` template.**

- **`etc/zshrc`**
  A minor configuration script for Zsh that applies a custom backspace keybind (`backward-delete-char-instant`) to address text rendering or line-editing visual glitches.

## Wrapper Scripts (`script/`)

- **`script/milieu-sync`**
  A first-launch or update script that handles the installation of higher-level toolchains and utilities into the user's isolated environment (`~/.milieu`). It uses `cargo-binstall` for Rust tools, `go install` for Go tools, and `uv tool install` for Python tools, keeping the environment clean and portable.

- **`script/col`**
  A simple substitution wrapper that strips backspace characters (`\b`) and mangled overstrikes from piped input text. Mostly used as part of the man-page rendering pipeline to produce readable output in non-traditional pagers.

- **`script/podman`**
  A thin wrapper that execs `libexec/podman-static/bin/podman` (the real static binary). Exists so `bin/podman` is not a symlink into libexec (which would bypass CONTAINERS_CONF). `MILIEU_DIR` and `CONTAINERS_CONF` are already set by `etc/profile`.

- **`script/less`**
  A wrapper around `busybox less` that intercepts unsupported flags (like `-T` and `-K`) and automatically pipes text through the `col` script to cleanly display nroff/mandoc output.

- **`script/nroff`**
  A compatibility wrapper mapping `nroff` calls to `mandoc -Tascii`, handling and safely ignoring standard nroff formatting registers to ensure seamless man-page parsing.

## Better Comments Guide

You can use the following tags to improve your code documentation. Place the tag immediately after the comment delimiter.

### 1. Alert (!)
Use this for critical warnings or errors.
- Example: `// ! This is an alert`

### 2. Query (?)
Use this for questions or things you are unsure about.
- Example: `// ? Should this method be exposed in the public API?`

### 3. TODO (TODO)
Use this for tasks that need to be completed.
- Example: `// TODO: Create some test cases`

### 4. Highlight (*)
Use this to make important information stand out.
- Example: `// * This is highlighted`

### Multi-line Usage
These tags also work inside JSDoc or block comments:
/**
 * * Important information is highlighted
 * ! Deprecated method, do not use
 * ? Question about implementation
 */
