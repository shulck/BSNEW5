//
//  SetlistDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct SetlistDetailView: View {
    @State var setlist: Setlist
    @State private var isEditing = false
    @State private var showAddSong = false
    @State private var showDeleteConfirmation = false
    @State private var showExportView = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    // Temporary storage for editing
    @State private var editName = ""
    
    var body: some View {
        VStack {
            // Header and information
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    TextField("Setlist name", text: $editName)
                        .font(.title2.bold())
                        .padding(.horizontal)
                } else {
                    Text(setlist.name)
                        .font(.title2.bold())
                        .padding(.horizontal)
                }
                
                HStack {
                    Text("\(setlist.songs.count) songs")
                    Spacer()
                    Text("Total duration: \(setlist.formattedTotalDuration)")
                        .bold()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            .padding(.top)
            
            Divider()
            
            // Song list
            List {
                ForEach(setlist.songs) { song in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text("BPM: \(song.bpm)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(song.formattedDuration)
                            .monospacedDigit()
                    }
                }
                .onDelete(perform: isEditing ? deleteSong : nil)
                .onMove(perform: isEditing ? moveSong : nil)
                
                if setlist.songs.isEmpty {
                    Text("Setlist is empty")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .listStyle(PlainListStyle())
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle(isEditing ? "Editing" : "Setlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if AppState.shared.hasEditPermission(for: .setlists) {
                        if isEditing {
                            Button {
                                saveChanges()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            
                            Button {
                                showAddSong = true
                            } label: {
                                Label("Add song", systemImage: "music.note.plus")
                            }
                        } else {
                            Button {
                                startEditing()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete setlist", systemImage: "trash")
                            }
                        }
                    }
                    
                    Button {
                        showExportView = true
                    } label: {
                        Label("Export to PDF", systemImage: "arrow.up.doc")
                    }
                } label: {
                    Label("Menu", systemImage: "ellipsis.circle")
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
        }
        .overlay(Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
        })
        .alert("Delete setlist?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSetlist()
            }
        } message: {
            Text("Are you sure you want to delete this setlist? This action cannot be undone.")
        }
        .sheet(isPresented: $showAddSong) {
            AddSongView(setlist: $setlist, onSave: {
                // After adding a song, update the setlist
                updateSetlist()
            })
        }
        .sheet(isPresented: $showExportView) {
            SetlistExportView(setlist: setlist)
        }
    }
    
    // Start editing
    private func startEditing() {
        editName = setlist.name
        isEditing = true
    }
    
    // Cancel editing
    private func cancelEditing() {
        editName = ""
        isEditing = false
    }
    
    // Save changes
    private func saveChanges() {
        // Update setlist name
        if !editName.isEmpty && editName != setlist.name {
            setlist.name = editName
        }
        
        updateSetlist()
        isEditing = false
    }
    
    // Delete song
    private func deleteSong(at offsets: IndexSet) {
        setlist.songs.remove(atOffsets: offsets)
    }
    
    // Move song
    private func moveSong(from source: IndexSet, to destination: Int) {
        setlist.songs.move(fromOffsets: source, toOffset: destination)
    }
    
    // Update setlist in database
    private func updateSetlist() {
        isLoading = true
        errorMessage = nil
        
        SetlistService.shared.updateSetlist(setlist) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if !success {
                    errorMessage = "Failed to save changes"
                }
            }
        }
    }
    
    // Delete setlist
    private func deleteSetlist() {
        SetlistService.shared.deleteSetlist(setlist)
        dismiss()
    }
}

// View for adding a song
struct AddSongView: View {
    @Binding var setlist: Setlist
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var bpm = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song Information")) {
                    TextField("Title", text: $title)
                    
                    HStack {
                        Text("Duration:")
                        TextField("Min", text: $minutes)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        Text(":")
                        TextField("Sec", text: $seconds)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                    }
                    
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSong()
                    }
                    .disabled(title.isEmpty || (minutes.isEmpty && seconds.isEmpty) || bpm.isEmpty)
                }
            }
        }
    }
    
    private func addSong() {
        guard !title.isEmpty else { return }
        
        let min = Int(minutes) ?? 0
        let sec = Int(seconds) ?? 0
        let bpmValue = Int(bpm) ?? 120
        
        // Check data validity
        if min == 0 && sec == 0 {
            return
        }
        
        // Create new song
        let newSong = Song(
            title: title,
            durationMinutes: min,
            durationSeconds: sec,
            bpm: bpmValue
        )
        
        // Add song to setlist
        setlist.songs.append(newSong)
        
        // Call save handler
        onSave()
        
        // Close modal
        dismiss()
    }
}
