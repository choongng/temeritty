use cfg_aliases::cfg_aliases;

fn main() {
    // Setup alias to reduce `cfg` boilerplate.
    cfg_aliases! {
        // Systems.
        android_platform: { target_os = "android" },
        ohos_platform: { target_env = "ohos" },
        wasm_platform: { target_family = "wasm" },
        macos_platform: { target_os = "macos" },
        ios_platform: { target_os = "ios" },
        apple: { any(ios_platform, macos_platform) },
        free_unix: { all(unix, not(apple), not(android_platform), not(ohos_platform)) },

        // Native displays.
        x11_platform: { all(feature = "x11", free_unix, not(wasm_platform)) },
        wayland_platform: { all(feature = "wayland", free_unix, not(wasm_platform)) },

        // Backends.
        // Temeritty patch: EGL on macOS too (ANGLE's libEGL.dylib); upstream has `not(apple)`.
        egl_backend: { all(feature = "egl", any(windows, unix), not(ios_platform), not(wasm_platform)) },
        glx_backend: { all(feature = "glx", x11_platform, not(wasm_platform)) },
        wgl_backend: { all(feature = "wgl", windows, not(wasm_platform)) },
        // Temeritty patch: behind the `cgl` feature, a default one; upstream has no feature.
        cgl_backend: { all(feature = "cgl", macos_platform, not(wasm_platform)) },
    }
}
