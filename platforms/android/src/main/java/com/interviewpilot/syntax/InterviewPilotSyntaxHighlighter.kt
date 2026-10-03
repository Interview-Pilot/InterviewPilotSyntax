package com.interviewpilot.syntax

import org.json.JSONObject
import java.nio.charset.StandardCharsets

public enum class SyntaxAppearance(internal val nativeValue: Int) {
    LIGHT(0),
    DARK(1)
}

public data class HighlightedCode(
    val recognizedLanguage: Boolean,
    val lines: List<HighlightedLine>
)

public data class HighlightedLine(val runs: List<HighlightedRun>)

public data class HighlightedRun(
    val text: String,
    val red: Int,
    val green: Int,
    val blue: Int,
    val alpha: Int,
    val style: Int
) {
    public val isBold: Boolean get() = style and STYLE_BOLD != 0
    public val isItalic: Boolean get() = style and STYLE_ITALIC != 0
    public val isUnderlined: Boolean get() = style and STYLE_UNDERLINE != 0

    private companion object {
        const val STYLE_BOLD = 1 shl 0
        const val STYLE_ITALIC = 1 shl 1
        const val STYLE_UNDERLINE = 1 shl 2
    }
}

public object InterviewPilotSyntaxHighlighter {
    public const val MAXIMUM_SOURCE_BYTE_COUNT: Int = 64 * 1024
    private const val MAXIMUM_LANGUAGE_BYTE_COUNT: Int = 64
    private const val PAYLOAD_VERSION: Int = 1
    private const val KNOWN_STYLE_BITS: Int = 0b111

    @JvmStatic
    public fun highlight(
        source: String,
        language: String?,
        appearance: SyntaxAppearance
    ): HighlightedCode? {
        if (source.toByteArray(StandardCharsets.UTF_8).size > MAXIMUM_SOURCE_BYTE_COUNT) return null
        if ((language?.toByteArray(StandardCharsets.UTF_8)?.size ?: 0) > MAXIMUM_LANGUAGE_BYTE_COUNT) return null

        val payload = NativeBridge.highlight(source, language, appearance.nativeValue) ?: return null
        return parsePayload(payload, expectedSource = source)
    }

    internal fun parsePayload(payload: String, expectedSource: String): HighlightedCode? = runCatching {
        val root = JSONObject(payload)
        if (root.getInt("v") != PAYLOAD_VERSION) return null

        val linesPayload = root.getJSONArray("l")
        val lines = buildList(linesPayload.length()) {
            repeat(linesPayload.length()) { lineIndex ->
                val runsPayload = linesPayload.getJSONObject(lineIndex).getJSONArray("r")
                add(HighlightedLine(buildList(runsPayload.length()) {
                    repeat(runsPayload.length()) { runIndex ->
                        val run = runsPayload.getJSONObject(runIndex)
                        val style = run.getInt("s")
                        if (style and KNOWN_STYLE_BITS.inv() != 0) return null
                        add(HighlightedRun(
                            text = run.getString("t"),
                            red = run.validColor("r") ?: return null,
                            green = run.validColor("g") ?: return null,
                            blue = run.validColor("b") ?: return null,
                            alpha = run.validColor("a") ?: return null,
                            style = style
                        ))
                    }
                }))
            }
        }
        val result = HighlightedCode(
            recognizedLanguage = root.getBoolean("r"),
            lines = lines
        )
        val rebuiltSource = result.lines.joinToString("\n") { line ->
            line.runs.joinToString(separator = "") { it.text }
        }
        result.takeIf { rebuiltSource == expectedSource }
    }.getOrNull()

    private fun JSONObject.validColor(key: String): Int? =
        getInt(key).takeIf { it in 0..255 }
}
