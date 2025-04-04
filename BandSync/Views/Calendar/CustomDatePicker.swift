import SwiftUI

// Helper structure for marking dates in the calendar
struct CalendarDateMarker: View {
    let date: Date
    let events: [Event]
    
    var body: some View {
        // Check if there are events on this date
        if hasEventsForDate() {
            VStack {
                Spacer()
                HStack(spacing: 3) {
                    // Display up to 3 markers for different types of events
                    ForEach(uniqueEventTypes().prefix(3), id: \.self) { eventType in
                        Circle()
                            .fill(Color(hex: eventType.color))
                            .frame(width: 6, height: 6)
                    }
                    
                    // If there are more than 3 types of events, show a "+" marker
                    if uniqueEventTypes().count > 3 {
                        Text("+")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 4)
            }
        } else {
            // Empty view if there are no events
            EmptyView()
        }
    }
    
    // Check for events on the selected date
    private func hasEventsForDate() -> Bool {
        return !eventsForDate().isEmpty
    }
    
    // Get the list of events for the given date
    private func eventsForDate() -> [Event] {
        return events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }
    
    // Get unique event types to display markers of different colors
    private func uniqueEventTypes() -> [EventType] {
        let types = eventsForDate().map { $0.type }
        return Array(Set(types))
    }
}

struct DateValue: Identifiable {
    let id = UUID().uuidString
    let day: Int
    let date: Date
}

struct CustomDatePicker: View {
    @Binding var selectedDate: Date
    let events: [Event]
    
    // Current month and year
    @State private var currentMonth = 0
    @State private var currentYear = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with month and year
            HStack {
                Button {
                    // Previous month
                    currentMonth -= 1
                    
                    if currentMonth < 0 {
                        currentMonth = 11
                        currentYear -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                
                Spacer()
                
                // Display current month and year
                Text(monthYearText())
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    // Next month
                    currentMonth += 1
                    
                    if currentMonth > 11 {
                        currentMonth = 0
                        currentYear += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            
            // Days of the week (fixed to use correct order from calendar)
            HStack(spacing: 0) {
                ForEach(Array(getDaysOfWeek().enumerated()), id: \.element) { index, day in
                    Text(day)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(isWeekend(at: index) ? .red : .primary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Dates of the current month
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(extractDates()) { dateValue in
                    // Date cell
                    VStack {
                        if dateValue.day != -1 {
                            // If the date belongs to the current month
                            Button {
                                selectedDate = dateValue.date
                            } label: {
                                ZStack {
                                    // Highlight the selected date
                                    if Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 35, height: 35)
                                    }
                                    
                                    // Highlight today's date
                                    if Calendar.current.isDateInToday(dateValue.date) && !Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) {
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 1.5)
                                            .frame(width: 35, height: 35)
                                    }
                                    
                                    // Day number
                                    Text("\(dateValue.day)")
                                        .font(.system(size: 16))
                                        .fontWeight(Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) ? .bold : .regular)
                                        .foregroundColor(
                                            Calendar.current.isDate(dateValue.date, inSameDayAs: selectedDate) ? .white :
                                                (Calendar.current.isDateInToday(dateValue.date) ? .blue : .primary)
                                        )
                                }
                            }
                            
                            // Event markers below the date
                            CalendarDateMarker(date: dateValue.date, events: events)
                                .frame(height: 6)
                        }
                    }
                    .frame(height: 45)
                }
            }
            
            Spacer()
        }
        .onAppear {
            // Initialize the current month and year
            let calendar = Calendar.current
            currentMonth = calendar.component(.month, from: selectedDate) - 1 // 0-based
            currentYear = calendar.component(.year, from: selectedDate)
        }
    }
    
    // Get the name of the month and year
    private func monthYearText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "LLLL yyyy" // Full month name and year
        
        // Create a date for the first day of the selected month
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth + 1, day: 1)) ?? Date()
        
        return dateFormatter.string(from: date)
    }
    
    // Fixed: Get correct days of week based on calendar's first weekday
    private func getDaysOfWeek() -> [String] {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.shortWeekdaySymbols
        
        // Get the first day of the week according to the user's locale (1-based, 1=Sunday, 2=Monday, etc.)
        let firstWeekday = calendar.firstWeekday
        
        // Rearrange the weekday symbols according to the first day of the week
        var arrangedWeekdaySymbols = [String]()
        for i in 0..<7 {
            let index = (firstWeekday - 1 + i) % 7
            arrangedWeekdaySymbols.append(weekdaySymbols[index])
        }
        
        return arrangedWeekdaySymbols
    }
    
    // Helper to determine if a day is a weekend based on its position in the week
    private func isWeekend(at index: Int) -> Bool {
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        
        // Calculate actual weekday (1-based, where 1 is Sunday)
        let weekday = (firstWeekday + index) % 7
        let actualWeekday = weekday == 0 ? 7 : weekday
        
        // In most locales, Saturday (7) and Sunday (1) are weekends
        return actualWeekday == 1 || actualWeekday == 7
    }
    
    // Extract dates of the current month - FIXED to properly align with days of week
    private func extractDates() -> [DateValue] {
        var dateValues = [DateValue]()
        
        let calendar = Calendar.current
        
        // Get the date for the first day of the selected month
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: currentYear, month: currentMonth + 1, day: 1)) else {
            return dateValues
        }
        
        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        
        // Get the weekday of the first day (1-7, where 1 is Sunday, 2 is Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate the number of empty cells needed before the first day
        // We need to adjust based on the calendar's first weekday
        let firstWeekdayIndex = (firstWeekday + 7 - calendar.firstWeekday) % 7
        
        // Add empty cells for days of the previous month
        for _ in 0..<firstWeekdayIndex {
            dateValues.append(DateValue(day: -1, date: Date()))
        }
        
        // Add days of the current month
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                dateValues.append(DateValue(day: day, date: date))
            }
        }
        
        return dateValues
    }
}

// Extension for converting a Hex string to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
