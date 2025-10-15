import Foundation

extension Date {
    /// Returns a relative time string (e.g., "2 hours ago", "3 days ago")
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a short relative time string (e.g., "2h", "3d")
    func shortRelativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a formatted date string for display in UI
    func displayString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns a compact date string for table cells
    func compactString() -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if abs(now.timeIntervalSince(self)) < 7 * 24 * 60 * 60 { // Less than a week
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // Day of week (e.g., "Mon")
            return formatter.string(from: self)
        } else if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // e.g., "Jan 15"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy" // e.g., "Jan 15, 2023"
            return formatter.string(from: self)
        }
    }
}

extension DateFormatter {
    /// Shared ISO8601 formatter for API responses
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Shared formatter for display dates
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Shared formatter for compact display
    static let compact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
