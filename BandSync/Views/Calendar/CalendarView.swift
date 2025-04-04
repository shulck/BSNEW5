//
//  CalendarView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 03.04.2025.
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var eventService = EventService.shared
    @State private var selectedDate = Date()
    @State private var showAddEvent = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom calendar with color-coded dates
                CustomDatePicker(selectedDate: $selectedDate, events: eventService.events)
                    .padding(.vertical)
                
                Divider()
                
                // Header section for selected day
                HStack {
                    Text(formatDate(selectedDate))
                        .font(.headline)
                    Spacer()
                    Text("\(eventsForSelectedDate().count) \(eventCountLabel(eventsForSelectedDate().count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // List of events for selected date
                if eventsForSelectedDate().isEmpty {
                    Spacer()
                    Text("No events for selected date")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(eventsForSelectedDate(), id: \.id) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                EventRowView(event: event)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                Button(action: {
                    showAddEvent = true
                }) {
                    Label("Add", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    eventService.fetchEvents(for: groupId)
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }
    
    // Get list of events for selected date
    private func eventsForSelectedDate() -> [Event] {
        eventService.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted { $0.date < $1.date } // Sort by time
    }
    
    // Format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    // Proper declension of the word "event"
    private func eventCountLabel(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "event"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "events"
        } else {
            return "events"
        }
    }
}
