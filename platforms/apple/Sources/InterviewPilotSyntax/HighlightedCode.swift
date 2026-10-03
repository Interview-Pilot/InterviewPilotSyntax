import SwiftUI

public struct HighlightedCode: Sendable, Equatable {
    public let recognizedLanguage: Bool
    public let lines: [Line]

    public struct Line: Sendable, Equatable {
        public let runs: [Run]

        public init(runs: [Run]) {
            self.runs = runs
        }
    }

    public struct Run: Sendable, Equatable {
        public let text: String
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8
        public let style: FontStyle

        public init(
            text: String,
            red: UInt8,
            green: UInt8,
            blue: UInt8,
            alpha: UInt8,
            style: FontStyle
        ) {
            self.text = text
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
            self.style = style
        }
    }

    public struct FontStyle: OptionSet, Sendable, Equatable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let bold = FontStyle(rawValue: 1 << 0)
        public static let italic = FontStyle(rawValue: 1 << 1)
        public static let underline = FontStyle(rawValue: 1 << 2)
    }

    public static func plain(_ source: String, color: Color) -> AttributedString {
        var attributed = AttributedString(source)
        attributed.foregroundColor = color
        return attributed
    }

    public func attributedString(fallbackColor: Color) -> AttributedString {
        var result = AttributedString()
        for lineIndex in lines.indices {
            if lineIndex > lines.startIndex {
                result.append(AttributedString("\n"))
            }
            for run in lines[lineIndex].runs {
                var segment = AttributedString(run.text)
                segment.foregroundColor = Color(
                    red: Double(run.red) / 255,
                    green: Double(run.green) / 255,
                    blue: Double(run.blue) / 255,
                    opacity: Double(run.alpha) / 255
                )
                var presentationIntent = InlinePresentationIntent()
                if run.style.contains(.bold) {
                    presentationIntent.insert(.stronglyEmphasized)
                }
                if run.style.contains(.italic) {
                    presentationIntent.insert(.emphasized)
                }
                if !presentationIntent.isEmpty {
                    segment.inlinePresentationIntent = presentationIntent
                }
                if run.style.contains(.underline) {
                    segment.underlineStyle = .single
                }
                result.append(segment)
            }
        }
        if result.characters.isEmpty {
            return Self.plain("", color: fallbackColor)
        }
        return result
    }
}
