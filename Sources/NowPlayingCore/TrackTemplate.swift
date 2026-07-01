import Foundation

public enum TrackVariable: String, CaseIterable {
    case title, artist, artists, album, year
}

/// Renders a user-defined menu-bar title template. A token is
/// `<` + optional prefix + variable + optional suffix + `>`; the prefix/suffix
/// render only when the variable has a non-empty value.
public enum TrackTemplate {
    enum Segment: Equatable {
        case literal(String)
        case token(prefix: String, variable: TrackVariable, suffix: String)
    }

    enum ParseError: Error, Equatable {
        case unclosed
        case unknownVariable(String)
    }

    /// Returns nil if the template is valid, otherwise a human-readable message.
    public static func validate(_ template: String) -> String? {
        switch parse(template) {
        case .success:
            return nil
        case .failure(.unclosed):
            return "Unclosed '<'"
        case .failure(.unknownVariable(let inner)):
            return "Unknown variable: <\(inner)>"
        }
    }

    public static func render(_ template: String, values: [TrackVariable: String]) -> String {
        guard case .success(let segments) = parse(template) else {
            return template
        }
        var output = ""
        for segment in segments {
            switch segment {
            case .literal(let text):
                output += text
            case .token(let prefix, let variable, let suffix):
                let value = values[variable] ?? ""
                if !value.isEmpty { output += prefix + value + suffix }
            }
        }
        return output
    }

    // MARK: - Parsing

    static func parse(_ template: String) -> Result<[Segment], ParseError> {
        let variables = TrackVariable.allCases.sorted { $0.rawValue.count > $1.rawValue.count }
        let chars = Array(template)
        var segments: [Segment] = []
        var literal = ""
        var i = 0

        while i < chars.count {
            guard chars[i] == "<" else {
                literal.append(chars[i])
                i += 1
                continue
            }
            guard let close = findClose(chars, from: i + 1) else {
                return .failure(.unclosed)
            }
            let inner = String(chars[(i + 1)..<close])
            guard let match = matchVariable(inner, variables: variables) else {
                return .failure(.unknownVariable(inner))
            }
            if !literal.isEmpty {
                segments.append(.literal(literal))
                literal = ""
            }
            segments.append(.token(prefix: match.prefix, variable: match.variable,
                                   suffix: match.suffix))
            i = close + 1
        }
        if !literal.isEmpty { segments.append(.literal(literal)) }
        return .success(segments)
    }

    private static func findClose(_ chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count {
            if chars[i] == ">" { return i }
            i += 1
        }
        return nil
    }

    private static func matchVariable(
        _ inner: String,
        variables: [TrackVariable]
    ) -> (prefix: String, variable: TrackVariable, suffix: String)? {
        let chars = Array(inner)
        guard !chars.isEmpty else { return nil }
        for start in 0..<chars.count {
            for variable in variables {
                let name = Array(variable.rawValue)
                guard start + name.count <= chars.count else { continue }
                if Array(chars[start..<(start + name.count)]) == name {
                    return (String(chars[0..<start]),
                            variable,
                            String(chars[(start + name.count)...]))
                }
            }
        }
        return nil
    }
}
