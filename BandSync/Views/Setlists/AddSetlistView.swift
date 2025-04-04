//
//  AddSetlistView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AddSetlistView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddSetlistView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var songs: [Song] = []
    @State private var newTitle: String = ""
    @State private var minutes: String = ""
    @State private var seconds: String = ""
    @State private var bpm: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Information")) {
                    TextField("Setlist name", text: $name)
                }

                Section(header: Text("Add song")) {
                    TextField("Title", text: $newTitle)
                    HStack {
                        TextField("Min", text: $minutes)
                            .keyboardType(.numberPad)
                        Text(":")
                        TextField("Sec", text: $seconds)
                            .keyboardType(.numberPad)
                    }
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)

                    Button("Add") {
                        guard let min = Int(minutes), let sec = Int(seconds), let bpmVal = Int(bpm), !newTitle.isEmpty else { return }
                        let song = Song(title: newTitle, durationMinutes: min, durationSeconds: sec, bpm: bpmVal)
                        songs.append(song)
                        newTitle = ""
                        minutes = ""
                        seconds = ""
                        bpm = ""
                    }
                }

                Section(header: Text("Songs")) {
                    ForEach(songs) { song in
                        HStack {
                            Text(song.title)
                            Spacer()
                            Text(song.formattedDuration)
                        }
                    }
                    .onDelete { indexSet in
                        songs.remove(atOffsets: indexSet)
                    }
                }

                Section {
                    HStack {
                        Text("Total duration")
                        Spacer()
                        Text(formattedTotalDuration)
                            .bold()
                    }
                }
            }

            .navigationTitle("Create Setlist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let uid = AppState.shared.user?.id,
                              let groupId = AppState.shared.user?.groupId,
                              !name.isEmpty
                        else { return }

                        let setlist = Setlist(
                            name: name,
                            userId: uid,
                            groupId: groupId,
                            isShared: true,
                            songs: songs
                        )

                        SetlistService.shared.addSetlist(setlist) { success in
                            if success {
                                dismiss()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formattedTotalDuration: String {
        let total = songs.reduce(0) { $0 + $1.totalSeconds }
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
