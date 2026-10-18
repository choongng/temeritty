# Temeritty patches to glutin_egl_sys 0.7.1

This is glutin_egl_sys 0.7.1 from crates.io (sha256
`4c4680ba6195f424febdc3ba46e7a42a0e58743f2edb115297b86d7f8ecc02d2`), used
through `[patch.crates-io]` in the workspace `Cargo.toml`. The crates.io
`.cargo-ok` marker is removed; everything else is as published except for
the change below, marked `Temeritty patch` in the source.

## 1. Build for macOS

- `build.rs`: generates the EGL bindings for a `darwin` target too (the
  same dynamically loaded `StructGenerator` bindings as Linux).
- `src/lib.rs`: the crate-level `cfg` includes `target_os = "macos"`.

Why: vendored glutin builds its EGL backend on macOS so that Temeritty can
use ANGLE's `libEGL.dylib` there (`vendor/glutin/PATCHES.md`, patch 3).
Upstream leaves macOS out because it has no system EGL.

## Rebasing

`diff -ru <crates.io glutin_egl_sys-0.7.1> vendor/glutin_egl_sys` shows the
whole patch.
