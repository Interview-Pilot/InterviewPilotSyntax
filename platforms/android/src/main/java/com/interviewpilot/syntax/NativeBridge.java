package com.interviewpilot.syntax;

final class NativeBridge {
    private static final boolean isAvailable;

    static {
        boolean loaded = false;
        try {
            System.loadLibrary("interview_pilot_syntax_android");
            loaded = true;
        } catch (LinkageError | SecurityException ignored) {
            // Highlighting is optional presentation; callers retain plain source.
        }
        isAvailable = loaded;
    }

    private NativeBridge() {}

    static String highlight(String source, String language, int appearance) {
        if (!isAvailable) return null;
        try {
            return highlightNative(source, language, appearance);
        } catch (LinkageError | RuntimeException ignored) {
            return null;
        }
    }

    private static native String highlightNative(
            String source,
            String language,
            int appearance
    );
}
