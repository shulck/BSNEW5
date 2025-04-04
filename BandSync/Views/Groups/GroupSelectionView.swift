//
//  GroupSelectionView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 04.04.2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct GroupSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var groupService = GroupService.shared
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showScanQR = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Контекст для сканирования QR-кода
    private let context = CIContext()
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                // Логотип и заголовок
                VStack(spacing: 15) {
                    Image(systemName: "music.mic")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .padding()
                        .foregroundColor(.blue)
                    
                    Text("Добро пожаловать в BandSync!")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("Для начала работы создайте новую группу или присоединитесь к существующей")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.secondary)
                }
                
                // Действия
                VStack(spacing: 15) {
                    // Кнопка "Создать группу"
                    Button(action: {
                        showCreateGroup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Создать новую группу")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    // Кнопка "Присоединиться к группе"
                    Button(action: {
                        showJoinGroup = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Присоединиться к группе")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    // Кнопка "Сканировать QR-код"
                    Button(action: {
                        showScanQR = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Сканировать QR-код")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Выход и смена пользователя
                VStack(spacing: 10) {
                    Button("Выйти из аккаунта") {
                        appState.logout()
                    }
                    .foregroundColor(.red)
                    
                    if let email = appState.user?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding()
            
            // Индикатор загрузки
            if isLoading || appState.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView()
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupView()
        }
        .sheet(isPresented: $showScanQR) {
            QRCodeScannerView(onCodeScanned: handleScannedCode)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Информация"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Обработка отсканированного QR-кода
    private func handleScannedCode(_ code: String) {
        // Закрываем сканер
        showScanQR = false
        
        // Проверяем минимальную длину кода (должен быть не менее 6 символов)
        guard code.count >= 6 else {
            alertMessage = "Неверный формат кода"
            showAlert = true
            return
        }
        
        // Присоединяемся к группе
        isLoading = true
        
        groupService.joinGroup(code: code) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Обновляем состояние приложения
                    appState.refreshAuthState()
                case .failure(let error):
                    alertMessage = "Ошибка: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// Представление для сканирования QR-кода
struct QRCodeScannerView: View {
    @Environment(\.dismiss) var dismiss
    let onCodeScanned: (String) -> Void
    @State private var isShowingScanner = false
    @State private var manualCode = ""
    @State private var showManualInput = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isShowingScanner {
                    Text("Наведите камеру на QR-код")
                        .font(.headline)
                        .padding()
                    
                    // Здесь можно было бы интегрировать реальный сканер QR-кодов через Camera или AVFoundation
                    // Для примера, создадим упрощенную симуляцию с задержкой
                    ZStack {
                        Color.black.opacity(0.1)
                            .frame(width: 250, height: 250)
                            .cornerRadius(10)
                        
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .frame(width: 180, height: 180)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    // Симуляция сканирования - просто для демонстрации
                    Button("Симулировать сканирование") {
                        // Случайно сгенерированный код
                        let randomCode = String(UUID().uuidString.prefix(6)).uppercased()
                        onCodeScanned(randomCode)
                    }
                    .padding()
                    
                    Text("В настоящей реализации здесь будет видеопоток с камеры")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        Text("Сканирование QR-кода")
                            .font(.title2.bold())
                        
                        Text("Нажмите кнопку, чтобы начать сканирование")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button(action: {
                            isShowingScanner = true
                        }) {
                            Label("Начать сканирование", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding()
                        
                        Button(action: {
                            showManualInput = true
                        }) {
                            Text("Ввести код вручную")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Сканировать QR-код")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Ввести код вручную", isPresented: $showManualInput) {
                TextField("Код приглашения", text: $manualCode)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                
                Button("Отмена", role: .cancel) {}
                
                Button("Применить") {
                    if !manualCode.isEmpty {
                        onCodeScanned(manualCode)
                    }
                }
            } message: {
                Text("Введите 6-значный код, полученный от другого участника")
            }
        }
    }
}
