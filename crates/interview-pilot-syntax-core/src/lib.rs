use serde::Serialize;
use std::sync::LazyLock;
use two_face::re_exports::syntect::{
    easy::HighlightLines,
    highlighting::{FontStyle, Theme, ThemeSet},
    parsing::{SyntaxReference, SyntaxSet},
    util::LinesWithEndings,
};

pub const MAX_SOURCE_BYTES: usize = 64 * 1024;
pub const MAX_LANGUAGE_BYTES: usize = 64;

static SYNTAX_SET: LazyLock<SyntaxSet> = LazyLock::new(two_face::syntax::extra_newlines);
static THEME_SET: LazyLock<ThemeSet> = LazyLock::new(ThemeSet::load_defaults);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Appearance {
    Light,
    Dark,
}

#[derive(Debug, Eq, PartialEq)]
pub enum HighlightError {
    SourceTooLarge,
    LanguageTooLarge,
    Engine,
}

#[derive(Debug, Serialize)]
pub struct HighlightedCode {
    #[serde(rename = "v")]
    pub version: u8,
    #[serde(rename = "r")]
    pub recognized_language: bool,
    #[serde(rename = "l")]
    pub lines: Vec<HighlightedLine>,
}

#[derive(Debug, Serialize)]
pub struct HighlightedLine {
    #[serde(rename = "r")]
    pub runs: Vec<HighlightedRun>,
}

#[derive(Debug, Serialize)]
pub struct HighlightedRun {
    #[serde(rename = "t")]
    pub text: String,
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
    #[serde(rename = "s")]
    pub style: u8,
}

pub fn highlight(
    source: &str,
    language: Option<&str>,
    appearance: Appearance,
) -> Result<HighlightedCode, HighlightError> {
    if source.len() > MAX_SOURCE_BYTES {
        return Err(HighlightError::SourceTooLarge);
    }
    if language.is_some_and(|value| value.len() > MAX_LANGUAGE_BYTES) {
        return Err(HighlightError::LanguageTooLarge);
    }

    let syntax = syntax_for_language(language);
    let recognized_language = syntax.is_some();
    let syntax = syntax.unwrap_or_else(|| SYNTAX_SET.find_syntax_plain_text());
    let theme = theme(appearance);
    let mut highlighter = HighlightLines::new(syntax, theme);
    let mut lines = Vec::new();

    for source_line in LinesWithEndings::from(source) {
        let highlighted = highlighter
            .highlight_line(source_line, &SYNTAX_SET)
            .map_err(|_| HighlightError::Engine)?;
        let mut runs = Vec::with_capacity(highlighted.len());

        for (style, text) in highlighted {
            let text = text.strip_suffix('\n').unwrap_or(text);
            let text = text.strip_suffix('\r').unwrap_or(text);
            if text.is_empty() {
                continue;
            }

            let run = HighlightedRun {
                text: text.to_owned(),
                r: style.foreground.r,
                g: style.foreground.g,
                b: style.foreground.b,
                a: style.foreground.a,
                style: font_style_bits(style.font_style),
            };

            if let Some(previous) = runs.last_mut() {
                if same_style(previous, &run) {
                    previous.text.push_str(&run.text);
                    continue;
                }
            }
            runs.push(run);
        }

        lines.push(HighlightedLine { runs });
    }

    if source.is_empty() || source.ends_with('\n') {
        lines.push(HighlightedLine { runs: Vec::new() });
    }

    Ok(HighlightedCode {
        version: 1,
        recognized_language,
        lines,
    })
}

fn theme(appearance: Appearance) -> &'static Theme {
    let name = match appearance {
        Appearance::Light => "InspiredGitHub",
        Appearance::Dark => "base16-ocean.dark",
    };
    &THEME_SET.themes[name]
}

fn syntax_for_language(language: Option<&str>) -> Option<&'static SyntaxReference> {
    let language = language?.trim();
    if language.is_empty() {
        return None;
    }

    let normalized = language.to_ascii_lowercase();
    let token = match normalized.as_str() {
        "javascript" => "js",
        "typescript" => "ts",
        "cplusplus" | "cpp" => "c++",
        "csharp" => "cs",
        "fsharp" => "fs",
        "golang" => "go",
        "objective-c" | "objectivec" => "m",
        "shell" | "zsh" => "sh",
        "common-lisp" | "commonlisp" => "lisp",
        "scheme" => "scm",
        "fortran" => "f90",
        "assembly" => "asm",
        value => value,
    };

    SYNTAX_SET
        .find_syntax_by_token(token)
        .or_else(|| SYNTAX_SET.find_syntax_by_name(language))
}

fn font_style_bits(style: FontStyle) -> u8 {
    let mut bits = 0;
    if style.contains(FontStyle::BOLD) {
        bits |= 1;
    }
    if style.contains(FontStyle::ITALIC) {
        bits |= 2;
    }
    if style.contains(FontStyle::UNDERLINE) {
        bits |= 4;
    }
    bits
}

fn same_style(lhs: &HighlightedRun, rhs: &HighlightedRun) -> bool {
    lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b && lhs.a == rhs.a && lhs.style == rhs.style
}

#[cfg(test)]
mod tests {
    use super::*;

    const BACKEND_IDENTIFIERS: &[&str] = &[
        "c",
        "python",
        "javascript",
        "typescript",
        "java",
        "cpp",
        "csharp",
        "go",
        "rust",
        "swift",
        "kotlin",
        "zig",
        "fsharp",
        "ocaml",
        "erlang",
        "objectiveC",
        "php",
        "ruby",
        "scala",
        "dart",
        "bash",
        "sql",
        "r",
        "matlab",
        "julia",
        "lua",
        "perl",
        "haskell",
        "elixir",
        "commonLisp",
        "scheme",
        "clojure",
        "groovy",
        "powershell",
        "vbnet",
        "fortran",
        "cobol",
        "assembly",
        "prolog",
        "ada",
    ];

    // The pure-Rust regex backend cannot load PowerShell's grammar. two-face
    // does not currently bundle VB.NET, COBOL, or Prolog grammars. These
    // identifiers intentionally take the verified plain-code fallback path.
    const PLAIN_FALLBACK_IDENTIFIERS: &[&str] = &["powershell", "vbnet", "cobol", "prolog"];

    #[test]
    fn recognizes_every_bundled_backend_language_identifier() {
        let missing: Vec<_> = BACKEND_IDENTIFIERS
            .iter()
            .filter(|language| !PLAIN_FALLBACK_IDENTIFIERS.contains(language))
            .filter(|language| syntax_for_language(Some(language)).is_none())
            .copied()
            .collect();
        assert!(missing.is_empty(), "missing syntaxes: {missing:?}");
    }

    #[test]
    fn unsupported_backend_grammars_preserve_source_through_plain_fallback() {
        for language in PLAIN_FALLBACK_IDENTIFIERS {
            let source = "value = calculate(input)";
            let output = highlight(source, Some(language), Appearance::Dark).unwrap();
            assert!(
                !output.recognized_language,
                "unexpected grammar for {language}"
            );
            assert_eq!(output.lines[0].runs[0].text, source);
        }
    }

    #[test]
    fn preserves_unicode_and_line_structure() {
        let source = "let greeting = \"你好 👋\"\nprint(greeting)\n";
        let output = highlight(source, Some("swift"), Appearance::Light).unwrap();
        let rebuilt = output
            .lines
            .iter()
            .map(|line| {
                line.runs
                    .iter()
                    .map(|run| run.text.as_str())
                    .collect::<String>()
            })
            .collect::<Vec<_>>()
            .join("\n");
        assert_eq!(rebuilt, source);
    }

    #[test]
    fn unsupported_language_returns_plain_text() {
        let source = "value <=> other";
        let output = highlight(source, Some("not-a-language"), Appearance::Dark).unwrap();
        assert!(!output.recognized_language);
        assert_eq!(output.lines[0].runs[0].text, source);
    }

    #[test]
    fn rejects_oversized_input() {
        let source = "a".repeat(MAX_SOURCE_BYTES + 1);
        assert_eq!(
            highlight(&source, Some("swift"), Appearance::Light).unwrap_err(),
            HighlightError::SourceTooLarge
        );
    }
}
