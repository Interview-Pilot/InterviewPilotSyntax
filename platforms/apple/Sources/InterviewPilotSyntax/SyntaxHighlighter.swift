import Foundation
import InterviewPilotSyntaxFFI

public enum SyntaxAppearance: UInt8, Sendable, Hashable {
    case light = 0
    case dark = 1
}

public enum InterviewPilotSyntaxHighlighter {
    public static let maximumSourceByteCount = 64 * 1024

    public static func highlight(
        _ source: String,
        language: String?,
        appearance: SyntaxAppearance
    ) -> HighlightedCode? {
        guard source.utf8.count <= maximumSourceByteCount else { return nil }
        guard (language?.utf8.count ?? 0) <= 64 else { return nil }

        let response: IPSyntaxBuffer = source.withCString { sourcePointer in
            withOptionalUTF8(language) { languagePointer, languageLength in
                ip_syntax_highlight(
                    UnsafeRawPointer(sourcePointer).assumingMemoryBound(to: UInt8.self),
                    UInt(source.utf8.count),
                    languagePointer,
                    UInt(languageLength),
                    appearance.rawValue
                )
            }
        }
        guard let bytes = response.bytes, response.length > 0 else { return nil }
        defer { ip_syntax_buffer_free(response) }

        let data = Data(bytes: bytes, count: Int(response.length))
        guard let payload = try? JSONDecoder().decode(HighlightPayload.self, from: data),
              payload.version == 1 else {
            return nil
        }
        return payload.model
    }

    private static func withOptionalUTF8<Result>(
        _ value: String?,
        _ body: (UnsafePointer<UInt8>?, Int) -> Result
    ) -> Result {
        guard let value else { return body(nil, 0) }
        return value.withCString { pointer in
            body(
                UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self),
                value.utf8.count
            )
        }
    }
}

private struct HighlightPayload: Decodable {
    let version: UInt8
    let recognizedLanguage: Bool
    let lines: [LinePayload]

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case recognizedLanguage = "r"
        case lines = "l"
    }

    var model: HighlightedCode {
        HighlightedCode(
            recognizedLanguage: recognizedLanguage,
            lines: lines.map { line in
                HighlightedCode.Line(runs: line.runs.map(\.model))
            }
        )
    }
}

private struct LinePayload: Decodable {
    let runs: [RunPayload]

    enum CodingKeys: String, CodingKey {
        case runs = "r"
    }
}

private struct RunPayload: Decodable {
    let text: String
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
    let style: UInt8

    enum CodingKeys: String, CodingKey {
        case text = "t"
        case red = "r"
        case green = "g"
        case blue = "b"
        case alpha = "a"
        case style = "s"
    }

    var model: HighlightedCode.Run {
        HighlightedCode.Run(
            text: text,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            style: HighlightedCode.FontStyle(rawValue: style)
        )
    }
}
