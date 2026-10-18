//! EGL platform Api.
//!
//! This platform is typically available on Linux, Android and other Unix-like
//! platforms.
//!
//! The EGL platform allows creating a [`Display`](self::display::Display) from
//! a [`Device`](self::device::Device).

use std::ffi::{self, CString};
use std::ops::{Deref, DerefMut};
use std::path::PathBuf;

use glutin_egl_sys::egl;

use libloading::Library;
use once_cell::sync::{Lazy, OnceCell};

#[cfg(unix)]
use libloading::os::unix as libloading_os;
#[cfg(windows)]
use libloading::os::windows as libloading_os;

use crate::error::{Error, ErrorKind, Result};
use crate::lib_loading::{SymLoading, SymWrapper};

pub mod config;
pub mod context;
pub mod device;
pub mod display;
pub mod surface;

// WARNING: If this implementation is ever changed to unload or replace the
// library, note that public API functions currently retirm `&'static str`ings
// out of it, which would become invalid.
pub(crate) static EGL: Lazy<Option<Egl>> = Lazy::new(|| {
    // Temeritty patch: a library chosen with `set_library_path` is the only one tried.
    if let Some(path) = LIBRARY_PATH.get() {
        let path = path.to_string_lossy();
        return unsafe { SymWrapper::new(&[&path]).map(Egl).ok() };
    }

    #[cfg(windows)]
    let paths = ["libEGL.dll", "atioglxx.dll"];

    #[cfg(not(windows))]
    let paths = ["libEGL.so.1", "libEGL.so"];

    unsafe { SymWrapper::new(&paths).map(Egl).ok() }
});

/// Temeritty patch: the EGL library to load instead of the system's, if set.
static LIBRARY_PATH: OnceCell<PathBuf> = OnceCell::new();

/// Temeritty patch: load EGL from `path` (for example ANGLE's `libEGL.so`) instead of
/// the system library, and only from there: if it does not load, EGL is
/// unavailable to this process.
///
/// Returns `false`, and changes nothing, when EGL was already loaded or a path
/// was already set: EGL is loaded once per process, by the first EGL call.
pub fn set_library_path(path: impl Into<PathBuf>) -> bool {
    Lazy::get(&EGL).is_none() && LIBRARY_PATH.set(path.into()).is_ok()
}

type EglGetProcAddress = unsafe extern "system" fn(*const ffi::c_void) -> *const ffi::c_void;
static EGL_GET_PROC_ADDRESS: OnceCell<libloading_os::Symbol<EglGetProcAddress>> = OnceCell::new();

/// EGL interface.
#[allow(missing_debug_implementations)]
pub struct Egl(SymWrapper<egl::Egl>);

unsafe impl Sync for Egl {}
unsafe impl Send for Egl {}

impl SymLoading for egl::Egl {
    unsafe fn load_with(lib: &Library) -> Self {
        let loader = move |sym_name: &'static str| -> *const ffi::c_void {
            unsafe {
                let sym_name = CString::new(sym_name.as_bytes()).unwrap();
                if let Ok(sym) = lib.get(sym_name.as_bytes_with_nul()) {
                    return *sym;
                }

                let egl_proc_address = EGL_GET_PROC_ADDRESS.get_or_init(|| {
                    let sym: libloading::Symbol<'_, EglGetProcAddress> =
                        lib.get(b"eglGetProcAddress\0").unwrap();
                    sym.into_raw()
                });

                // The symbol was not available in the library, so ask eglGetProcAddress for it.
                // Note that eglGetProcAddress was only able to look up extension
                // functions prior to EGL 1.5, hence this two-part dance.
                (egl_proc_address)(sym_name.as_bytes_with_nul().as_ptr() as *const ffi::c_void)
            }
        };

        egl::BindWaylandDisplayWL::load_with(loader);
        egl::UnbindWaylandDisplayWL::load_with(loader);
        egl::QueryWaylandBufferWL::load_with(loader);
        egl::CreateWaylandBufferFromImageWL::load_with(loader);

        Self::load_with(loader)
    }
}

impl Deref for Egl {
    type Target = egl::Egl;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl DerefMut for Egl {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}

/// Obtain the error from the EGL.
fn check_error() -> Result<()> {
    let egl = EGL.as_ref().unwrap();
    unsafe {
        let raw_code = egl.GetError() as egl::types::EGLenum;
        let kind = match raw_code {
            egl::SUCCESS => return Ok(()),
            egl::NOT_INITIALIZED => ErrorKind::InitializationFailed,
            egl::BAD_ACCESS => ErrorKind::BadAccess,
            egl::BAD_ALLOC => ErrorKind::OutOfMemory,
            egl::BAD_ATTRIBUTE => ErrorKind::BadAttribute,
            egl::BAD_CONTEXT => ErrorKind::BadContext,
            egl::BAD_CONFIG => ErrorKind::BadConfig,
            egl::BAD_CURRENT_SURFACE => ErrorKind::BadCurrentSurface,
            egl::BAD_DISPLAY => ErrorKind::BadDisplay,
            egl::BAD_SURFACE => ErrorKind::BadSurface,
            egl::BAD_MATCH => ErrorKind::BadMatch,
            egl::BAD_PARAMETER => ErrorKind::BadParameter,
            egl::BAD_NATIVE_PIXMAP => ErrorKind::BadNativePixmap,
            egl::BAD_NATIVE_WINDOW => ErrorKind::BadNativeWindow,
            egl::CONTEXT_LOST => ErrorKind::ContextLost,
            _ => ErrorKind::Misc,
        };

        Err(Error::new(Some(raw_code as i64), None, kind))
    }
}
