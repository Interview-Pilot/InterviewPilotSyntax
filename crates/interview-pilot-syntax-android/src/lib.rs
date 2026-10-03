use interview_pilot_syntax_core::{highlight, Appearance};
use jni::{
    objects::{JClass, JString},
    sys::{jint, jstring, JNI_ERR, JNI_VERSION_1_6},
    JNIEnv, JavaVM, NativeMethod,
};
use std::{
    ffi::c_void,
    panic::{catch_unwind, AssertUnwindSafe},
    ptr,
};

const NATIVE_BRIDGE_CLASS: &str = "com/interviewpilot/syntax/NativeBridge";
const HIGHLIGHT_SIGNATURE: &str = "(Ljava/lang/String;Ljava/lang/String;I)Ljava/lang/String;";

#[no_mangle]
pub extern "system" fn JNI_OnLoad(vm: JavaVM, _: *mut c_void) -> jint {
    register_native_methods(vm).unwrap_or(JNI_ERR)
}

fn register_native_methods(vm: JavaVM) -> Result<jint, jni::errors::Error> {
    let mut env = vm.get_env()?;
    let bridge = env.find_class(NATIVE_BRIDGE_CLASS)?;
    let methods = [NativeMethod {
        name: "highlightNative".into(),
        sig: HIGHLIGHT_SIGNATURE.into(),
        fn_ptr: highlight_native as *mut c_void,
    }];
    env.register_native_methods(bridge, &methods)?;
    Ok(JNI_VERSION_1_6)
}

extern "system" fn highlight_native(
    mut env: JNIEnv,
    _: JClass,
    source: JString,
    language: JString,
    appearance: jint,
) -> jstring {
    catch_unwind(AssertUnwindSafe(|| {
        highlight_native_impl(&mut env, source, language, appearance)
    }))
    .unwrap_or(ptr::null_mut())
}

fn highlight_native_impl(
    env: &mut JNIEnv,
    source: JString,
    language: JString,
    appearance: jint,
) -> jstring {
    let Ok(source) = env.get_string(&source) else {
        return ptr::null_mut();
    };
    let source = source.to_string_lossy();

    let language = if language.as_raw().is_null() {
        None
    } else {
        let Ok(language) = env.get_string(&language) else {
            return ptr::null_mut();
        };
        Some(language.to_string_lossy().into_owned())
    };

    let appearance = match appearance {
        0 => Appearance::Light,
        1 => Appearance::Dark,
        _ => return ptr::null_mut(),
    };
    let Ok(highlighted) = highlight(&source, language.as_deref(), appearance) else {
        return ptr::null_mut();
    };
    let Ok(payload) = serde_json::to_string(&highlighted) else {
        return ptr::null_mut();
    };
    let Ok(result) = env.new_string(payload) else {
        return ptr::null_mut();
    };
    result.into_raw()
}
