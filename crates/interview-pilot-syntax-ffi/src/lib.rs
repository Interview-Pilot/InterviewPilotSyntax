use interview_pilot_syntax_core::{highlight, Appearance, MAX_LANGUAGE_BYTES, MAX_SOURCE_BYTES};
use std::{
    panic::{catch_unwind, AssertUnwindSafe},
    ptr, slice, str,
};

#[repr(C)]
pub struct IPSyntaxBuffer {
    bytes: *const u8,
    length: usize,
}

impl IPSyntaxBuffer {
    const EMPTY: Self = Self {
        bytes: ptr::null(),
        length: 0,
    };
}

#[no_mangle]
pub unsafe extern "C" fn ip_syntax_highlight(
    source: *const u8,
    source_length: usize,
    language: *const u8,
    language_length: usize,
    appearance: u8,
) -> IPSyntaxBuffer {
    catch_unwind(AssertUnwindSafe(|| unsafe {
        highlight_impl(source, source_length, language, language_length, appearance)
    }))
    .unwrap_or(IPSyntaxBuffer::EMPTY)
}

unsafe fn highlight_impl(
    source: *const u8,
    source_length: usize,
    language: *const u8,
    language_length: usize,
    appearance: u8,
) -> IPSyntaxBuffer {
    // Validate caller-provided lengths before constructing borrowed slices.
    if source_length > MAX_SOURCE_BYTES || language_length > MAX_LANGUAGE_BYTES {
        return IPSyntaxBuffer::EMPTY;
    }

    let Some(source) = borrowed_utf8(source, source_length) else {
        return IPSyntaxBuffer::EMPTY;
    };
    let language = if language_length == 0 {
        None
    } else {
        let Some(value) = borrowed_utf8(language, language_length) else {
            return IPSyntaxBuffer::EMPTY;
        };
        Some(value)
    };
    let appearance = match appearance {
        0 => Appearance::Light,
        1 => Appearance::Dark,
        _ => return IPSyntaxBuffer::EMPTY,
    };

    let Ok(output) = highlight(source, language, appearance) else {
        return IPSyntaxBuffer::EMPTY;
    };
    let Ok(json) = serde_json::to_vec(&output) else {
        return IPSyntaxBuffer::EMPTY;
    };

    let boxed = json.into_boxed_slice();
    let buffer = IPSyntaxBuffer {
        bytes: boxed.as_ptr(),
        length: boxed.len(),
    };
    std::mem::forget(boxed);
    buffer
}

#[no_mangle]
pub unsafe extern "C" fn ip_syntax_buffer_free(buffer: IPSyntaxBuffer) {
    if buffer.bytes.is_null() || buffer.length == 0 {
        return;
    }
    let slice = ptr::slice_from_raw_parts_mut(buffer.bytes as *mut u8, buffer.length);
    drop(Box::from_raw(slice));
}

unsafe fn borrowed_utf8<'a>(bytes: *const u8, length: usize) -> Option<&'a str> {
    if length == 0 {
        return Some("");
    }
    if bytes.is_null() {
        return None;
    }
    str::from_utf8(slice::from_raw_parts(bytes, length)).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ffi_round_trip_and_release() {
        let source = "let value = 42";
        let language = "swift";
        let buffer = unsafe {
            ip_syntax_highlight(
                source.as_ptr(),
                source.len(),
                language.as_ptr(),
                language.len(),
                0,
            )
        };
        assert!(!buffer.bytes.is_null());
        let json = unsafe { slice::from_raw_parts(buffer.bytes, buffer.length) };
        let value: serde_json::Value = serde_json::from_slice(json).unwrap();
        assert_eq!(value["v"], 1);
        unsafe { ip_syntax_buffer_free(buffer) };
    }

    #[test]
    fn rejects_invalid_utf8() {
        let source = [0xff];
        let buffer =
            unsafe { ip_syntax_highlight(source.as_ptr(), source.len(), ptr::null(), 0, 0) };
        assert!(buffer.bytes.is_null());
        assert_eq!(buffer.length, 0);
    }

    #[test]
    fn rejects_oversized_lengths_before_reading_caller_memory() {
        let source = b"a";
        let buffer = unsafe {
            ip_syntax_highlight(source.as_ptr(), MAX_SOURCE_BYTES + 1, ptr::null(), 0, 0)
        };
        assert!(buffer.bytes.is_null());
        assert_eq!(buffer.length, 0);
    }
}
