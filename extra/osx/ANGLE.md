# ANGLE in Temeritty.app

On macOS Temeritty draws through ANGLE's OpenGL ES on its Metal backend.
Apple's OpenGL (CGL) is deprecated and draws a blank window on current
macOS, so there is no fallback: without ANGLE the terminal does not start,
and the error names where it looked.

## Building it

`make angle` builds ANGLE for the host architecture and copies
`libEGL.dylib` and `libGLESv2.dylib` beside `target/debug/alacritty` and
`target/release/alacritty`, so `cargo run` works. `make app` builds it too
and puts it in `Contents/Frameworks`, with the licence notices in
`Contents/Resources/THIRD-PARTY-NOTICES.txt`. `make app-universal` builds
arm64 and x64 and joins each library with `lipo`.

All three run `extra/osx/build-angle.sh OUT_DIR [ARCH...]`, which:

- clones depot_tools and ANGLE into `ANGLE_CACHE` (default
  `~/.cache/temeritty`), outside the repository so that `cargo clean` does not
  cost a fresh sync;
- checks out the pinned commit (`ANGLE_COMMIT` in the script) and runs
  `gclient sync` once per commit;
- configures with `gn` for the Metal backend alone (no OpenGL, Vulkan,
  SwiftShader or WebGPU backends) and builds the two libraries with
  `autoninja`;
- writes `THIRD-PARTY-NOTICES.txt`: ANGLE's licence, then the licence file of
  each `third_party` directory the two libraries depend on, as `gn desc`
  lists them and each directory's `README.chromium` names its licence.

It needs Xcode (not only the Command Line Tools) with its Metal toolchain
(`xcodebuild -downloadComponent MetalToolchain`), git and Python 3. The first
sync downloads several gigabytes; later builds reuse the checkout.

## Where Temeritty looks

The executable's directory, after resolving symlinks, then `../Frameworks`
beside it (`Contents/Frameworks` in the app). The first that holds
`libEGL.dylib` is used: `alacritty/src/renderer/angle.rs`. Temeritty loads it
by its full path; ANGLE's libEGL opens `libGLESv2.dylib` from its own
directory.

## The glutin changes

glutin and glutin_egl_sys leave EGL out of Apple targets. Both are vendored
(`vendor/glutin`, `vendor/glutin_egl_sys`, each with a `PATCHES.md`) so that
EGL builds on macOS and the display can be asked for ANGLE's Metal backend.
glutin gives ANGLE the view's `CALayer`, since ANGLE's Metal backend accepts
only a `CALayer*` as the native window.

## Signing

`make app` signs the bundle ad hoc (`codesign --force --deep --sign -`),
which covers the two libraries. A Developer ID build with the hardened
runtime would sign `Contents/Frameworks/*.dylib` first, then the app, and be
notarised; neither is done.

## Updating ANGLE

Pick a commit, usually the head of a `chromium/NNNN` branch, set
`ANGLE_COMMIT` in `build-angle.sh`, and rebuild. Check that the libraries
still load only system libraries (`otool -L`) and read the regenerated
notices.
