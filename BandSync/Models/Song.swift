//
//  Song.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  Song.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

struct Song: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var title: String
    var durationMinutes: Int
    var durationSeconds: Int
    var bpm: Int

    var totalSeconds: Int {
        return durationMinutes * 60 + durationSeconds
    }

    var formattedDuration: String {
        String(format: "%02d:%02d", durationMinutes, durationSeconds)
    }
}
