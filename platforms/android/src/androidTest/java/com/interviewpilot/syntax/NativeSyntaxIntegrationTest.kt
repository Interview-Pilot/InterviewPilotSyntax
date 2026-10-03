package com.interviewpilot.syntax

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeSyntaxIntegrationTest {
    @Test
    fun nativeHighlightingPreservesUnicodeSource() {
        val source = "val greeting = \"你好 👋\"\nprintln(greeting)"

        val result = InterviewPilotSyntaxHighlighter.highlight(
            source = source,
            language = "kotlin",
            appearance = SyntaxAppearance.DARK
        )

        assertTrue(result?.recognizedLanguage == true)
        assertEquals(
            source,
            result?.lines?.joinToString("\n") { line ->
                line.runs.joinToString(separator = "") { it.text }
            }
        )
    }
}
