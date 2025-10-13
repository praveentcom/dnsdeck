import Foundation

extension String {
    /// Trims whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if the string is not empty after trimming
    var isNotEmpty: Bool {
        !trimmed.isEmpty
    }

    /// Capitalizes the first letter of each word
    var capitalizedWords: String {
        capitalized
    }
}

extension String {
    /// Validates if the string is a valid domain name
    var isValidDomain: Bool {
        let domainRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        return NSPredicate(format: "SELF MATCHES %@", domainRegex).evaluate(with: self)
    }

    /// Validates if the string is a valid IPv4 address
    var isValidIPv4: Bool {
        var sin = sockaddr_in()
        return withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr) == 1
        }
    }

    /// Validates if the string is a valid IPv6 address
    var isValidIPv6: Bool {
        var sin6 = sockaddr_in6()
        return withCString { cstring in
            inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1
        }
    }
}
