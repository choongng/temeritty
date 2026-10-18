//! GL on macOS, through ANGLE's Metal backend: CGL draws nothing on current macOS.
//!
//! ANGLE is built from source and bundled; see `extra/osx/ANGLE.md`.

use std::error::Error;
use std::fmt;
use std::path::{Path, PathBuf};

use glutin::api::egl;
use glutin::display::Display;
use log::info;
use winit::raw_window_handle::RawDisplayHandle;

use crate::config::window::DEFAULT_NAME;

const LIB_EGL: &str = "libEGL.dylib";

/// Opened by libEGL from its own directory.
const LIB_GLES: &str = "libGLESv2.dylib";

// EGL_ANGLE_platform_angle and EGL_ANGLE_platform_angle_metal (EGL/eglext_angle.h).
const PLATFORM_ANGLE_TYPE: i32 = 0x3203;
const PLATFORM_ANGLE_TYPE_METAL: i32 = 0x3489;

/// Why ANGLE could not give a display.
#[derive(Debug)]
pub struct AngleError(String);

impl fmt::Display for AngleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "ANGLE: {}", self.0)
    }
}

impl Error for AngleError {}

/// Where ANGLE is looked for: beside the executable (`make angle`), then the bundle's Frameworks.
fn angle_dirs() -> Vec<PathBuf> {
    // Canonical, so a symlink to the bundled executable still finds the bundle.
    let exe_dir = std::env::current_exe()
        .ok()
        .map(|exe| exe.canonicalize().unwrap_or(exe))
        .and_then(|exe| exe.parent().map(Path::to_path_buf))
        .unwrap_or_default();
    let frameworks = exe_dir.join("../Frameworks");
    vec![exe_dir, frameworks]
}

/// Create the GL display on ANGLE's Metal backend.
pub fn create_display(raw_display_handle: RawDisplayHandle) -> Result<Display, AngleError> {
    let dirs = angle_dirs();
    let Some(dir) = dirs.iter().find(|dir| dir.join(LIB_EGL).is_file()) else {
        let tried: Vec<_> =
            dirs.iter().map(|dir| dir.join(LIB_EGL).display().to_string()).collect();
        return Err(AngleError(format!(
            "no {}; build ANGLE with `make angle` or run {DEFAULT_NAME}.app",
            tried.join(" or ")
        )));
    };
    let lib = dir.join(LIB_EGL);

    // Preload libGLESv2 so a load failure names it. Never unloaded, like EGL.
    let gles = dir.join(LIB_GLES);
    match unsafe { libloading::Library::new(&gles) } {
        Ok(gles) => std::mem::forget(gles),
        Err(err) => return Err(AngleError(format!("{}: {err}", gles.display()))),
    }

    if !egl::set_library_path(&lib) {
        return Err(AngleError("EGL was loaded before ANGLE".into()));
    }

    let attribs = [PLATFORM_ANGLE_TYPE, PLATFORM_ANGLE_TYPE_METAL];
    let display = unsafe { egl::display::Display::with_angle(raw_display_handle, &attribs) }
        .map_err(|err| AngleError(format!("Metal backend from {}: {err}", lib.display())))?;
    info!("Using ANGLE's Metal backend from {}", lib.display());
    Ok(Display::Egl(display))
}
