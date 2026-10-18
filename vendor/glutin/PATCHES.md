# Temeritty patches to glutin 0.32.3

This is glutin 0.32.3 from crates.io (sha256
`12124de845cacfebedff80e877bb37b5b75c34c5a4c89e47e1cdd67fb6041325`), used
through `[patch.crates-io]` in the workspace `Cargo.toml`. The crates.io
`.cargo-ok` marker is removed; everything else is as published except for
the three changes below. Each is marked `Temeritty patch` in the source. The
first two are additions: no existing behaviour changes unless they are
called. The third adds the EGL backend to macOS builds.

## 1. Load EGL from a given path

`src/api/egl/mod.rs`: `glutin::api::egl::set_library_path(path)`. Called
before the first EGL use, it makes the `EGL` loader open that file only,
instead of `libEGL.so.1` or `libEGL.so` by name. It returns `false` if EGL
is already loaded or a path is already set.

Why: ANGLE's library is named `libEGL.so` like the system's, and glutin
tries `libEGL.so.1` first, which resolves to the system EGL even with
`LD_LIBRARY_PATH` set. On macOS there is no system EGL to find, and
Temeritty loads ANGLE's `libEGL.dylib` from its app bundle.

## 2. Create an ANGLE display with backend attributes

`src/api/egl/display.rs`: `Display::with_angle(raw_display, attribs)`.
It calls `eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE, native
display, attribs + EGL_NONE)`, where the native display is the Xlib or
Wayland display pointer, or `EGL_DEFAULT_DISPLAY` for any other handle.
Then it initialises the display as `Display::new` does. Like glutin's
Windows ANGLE path, the display is the legacy kind, so window surfaces
use `eglCreateWindowSurface`.

Why: ANGLE lists neither `EGL_KHR_platform_x11` nor
`EGL_EXT_platform_x11`, so `Display::new` falls back to legacy
`eglGetDisplay` on X11, and that always gets ANGLE's default backend.
Choosing Vulkan, SwiftShader, OpenGL ES or Metal requires
`EGL_PLATFORM_ANGLE_ANGLE` and `EGL_PLATFORM_ANGLE_TYPE_ANGLE`. glutin
uses `EGL_PLATFORM_ANGLE_ANGLE` only for Windows handles, and with no
attributes.

## 3. EGL on macOS, for ANGLE

- `build.rs`: `egl_backend` excludes iOS instead of all Apple targets, so
  macOS builds both CGL and EGL.
- `Cargo.toml`: `glutin_egl_sys` is an optional macOS dependency, enabled
  by the `egl` feature as on the other platforms.
- `src/api/egl/surface.rs`: an AppKit window handle becomes the view's
  `CALayer`. The view is made layer-backed (`setWantsLayer:`) and its
  `layer` is retained for the life of the surface and passed to
  `eglCreateWindowSurface`.

Why: ANGLE builds `libEGL.dylib` for macOS, and Temeritty draws through it
there, on ANGLE's Metal backend. ANGLE's Metal and CGL backends
accept only a `CALayer*` as `EGLNativeWindowType`, not an `NSView*`.
`Display::with_angle` already passes `EGL_DEFAULT_DISPLAY` for an AppKit
display handle.

glutin_egl_sys 0.7.1 also leaves macOS out (its `build.rs` generates no
bindings for a darwin target and `src/lib.rs` is cfg'd off), so it is
vendored too, in `vendor/glutin_egl_sys` with its own `[patch.crates-io]`
entry; `vendor/glutin_egl_sys/PATCHES.md` has its two-line change.

See `extra/osx/ANGLE.md` for how Temeritty builds and bundles ANGLE.

## Rebasing

`diff -ru <crates.io glutin-0.32.3> vendor/glutin` shows the whole patch.
