use objc2::runtime::AnyObject;
use objc2_foundation::{NSDictionary, NSProcessInfo, NSString, NSUserDefaults, ns_string};

use crate::config::window::DEFAULT_NAME;

pub mod locale;
pub mod proc;

/// Name the app menu's About, Hide and Quit items after the app; call before the event loop.
pub fn set_process_name() {
    NSProcessInfo::processInfo().setProcessName(&NSString::from_str(DEFAULT_NAME));
}

pub fn disable_autofill() {
    unsafe {
        NSUserDefaults::standardUserDefaults().registerDefaults(
            &NSDictionary::<NSString, AnyObject>::from_slices(
                &[ns_string!("NSAutoFillHeuristicControllerEnabled")],
                &[ns_string!("NO")],
            ),
        );
    }
}
