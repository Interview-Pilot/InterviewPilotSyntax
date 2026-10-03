package com.interviewpilot.syntax

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InterviewPilotSyntaxHighlighterTest {
    @Test
    fun parsesPayloadWithoutChangingUnicodeSource() {
        val source = "val greeting = \"你好 👋\"\nprintln(greeting)"
        val payload = """{"v":1,"r":true,"l":[{"r":[{"t":"val greeting = ","r":1,"g":2,"b":3,"a":255,"s":1},{"t":"\"你好 👋\"","r":4,"g":5,"b":6,"a":255,"s":0}]},{"r":[{"t":"println(greeting)","r":7,"g":8,"b":9,"a":255,"s":2}]}]}"""

        val result = InterviewPilotSyntaxHighlighter.parsePayload(payload, source)

        assertEquals(source, result?.lines?.joinToString("\n") { line -> line.runs.joinToString("") { it.text } })
        assertTrue(result?.recognizedLanguage == true)
        assertTrue(result?.lines?.first()?.runs?.first()?.isBold == true)
        assertTrue(result?.lines?.last()?.runs?.first()?.isItalic == true)
    }

    @Test
    fun preservesPlainFallbackPayload() {
        val source = "value <=> other"
        val payload = """{"v":1,"r":false,"l":[{"r":[{"t":"value <=> other","r":20,"g":21,"b":22,"a":255,"s":0}]}]}"""

        val result = InterviewPilotSyntaxHighlighter.parsePayload(payload, source)

        assertFalse(result?.recognizedLanguage ?: true)
    }

    @Test
    fun rejectsPayloadThatChangesSource() {
        val payload = """{"v":1,"r":true,"l":[{"r":[{"t":"changed","r":1,"g":2,"b":3,"a":255,"s":0}]}]}"""

        assertNull(InterviewPilotSyntaxHighlighter.parsePayload(payload, "original"))
    }

    @Test
    fun rejectsUnknownVersionStyleAndInvalidColor() {
        val unknownVersion = """{"v":2,"r":true,"l":[]}"""
        val unknownStyle = """{"v":1,"r":true,"l":[{"r":[{"t":"x","r":1,"g":2,"b":3,"a":255,"s":8}]}]}"""
        val invalidColor = """{"v":1,"r":true,"l":[{"r":[{"t":"x","r":256,"g":2,"b":3,"a":255,"s":0}]}]}"""

        assertNull(InterviewPilotSyntaxHighlighter.parsePayload(unknownVersion, ""))
        assertNull(InterviewPilotSyntaxHighlighter.parsePayload(unknownStyle, "x"))
        assertNull(InterviewPilotSyntaxHighlighter.parsePayload(invalidColor, "x"))
    }
}
