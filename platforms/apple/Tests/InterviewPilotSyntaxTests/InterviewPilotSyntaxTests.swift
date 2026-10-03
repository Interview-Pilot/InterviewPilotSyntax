import Testing
@testable import InterviewPilotSyntax

@Test func highlightsSwiftWithoutChangingSource() {
    let source = "let greeting = \"你好 👋\"\nprint(greeting)"
    let result = InterviewPilotSyntaxHighlighter.highlight(
        source,
        language: "swift",
        appearance: .light
    )

    #expect(result?.recognizedLanguage == true)
    let rebuilt = result?.lines
        .map { $0.runs.map(\.text).joined() }
        .joined(separator: "\n")
    #expect(rebuilt == source)
}
@Test func unsupportedLanguageReturnsPlainRuns() {
    let result = InterviewPilotSyntaxHighlighter.highlight(
        "value <=> other",
        language: "not-a-language",
        appearance: .dark
    )

    #expect(result?.recognizedLanguage == false)
    #expect(result?.lines.first?.runs.map(\.text).joined() == "value <=> other")
}

@Test func rejectsOversizedInputBeforeFFI() {
    let source = String(repeating: "a", count: InterviewPilotSyntaxHighlighter.maximumSourceByteCount + 1)
    #expect(
        InterviewPilotSyntaxHighlighter.highlight(
            source,
            language: "swift",
            appearance: .light
        ) == nil
    )
}
