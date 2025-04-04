//
//  InviteUsersQRView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 04.04.2025.
//


//
//  InviteUsersQRView.swift
//  BandSync
//
//  Created by Claude AI on 04.04.2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteUsersQRView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupService = GroupService.shared
    @State private var inviteEmail = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var qrCode: UIImage?
    
    // Контекст для генерации QR-кода
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Секция QR-кода
                    VStack(spacing: 15) {
                        Text("Отсканируйте QR-код")
                            .font(.headline)
                        
                        if let qrCode = qrCode {
                            Image(uiImage: qrCode)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Divider()
                    
                    // Поделиться приглашением
                    VStack(spacing: 15) {
                        Text("Поделиться приглашением")
                            .font(.headline)
                        
                        Button(action: shareInvitation) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Пригласить участников")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Информация"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }
                }
            )
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                    
                    // Генерация QR-кода при появлении экрана
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let code = groupService.group?.code {
                            generateQRCode(from: code)
                        }
                    }
                }
            }
        }
    }
    
    // Отправка приглашения
    private func sendInvite() {
        guard let groupId = groupService.group?.id else {
            message = "Ошибка: не удалось загрузить информацию о группе"
            return
        }
        
        isLoading = true
        
        groupService.inviteUserByEmail(email: inviteEmail, to: groupId) { result in
            isLoading = false
            
            switch result {
            case .success:
                message = "Приглашение успешно отправлено!"
                inviteEmail = ""
            case .failure(let error):
                message = "Ошибка: \(error.localizedDescription)"
            }
        }
    }
    
    // Функция для генерации QR-кода
    private func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        // Устанавливаем коррекцию ошибок до максимума для лучшей читаемости
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                // Создаем изображение с высоким разрешением
                let uiImage = UIImage(cgImage: cgimg)
                
                // Создаем увеличенное изображение для лучшей четкости
                let size = CGSize(width: 1024, height: 1024)
                UIGraphicsBeginImageContext(size)
                uiImage.draw(in: CGRect(origin: .zero, size: size))
                if let scaledImage = UIGraphicsGetImageFromCurrentImageContext() {
                    DispatchQueue.main.async {
                        self.qrCode = scaledImage
                    }
                }
                UIGraphicsEndImageContext()
            }
        }
    }
    
    // Функция для шеринга приглашения
    private func shareInvitation() {
        guard let groupName = groupService.group?.name,
              let code = groupService.group?.code else {
            alertMessage = "Информация о группе недоступна"
            showAlert = true
            return
        }
        
        // Создаем текст для шеринга
        let shareText = "Приглашение в группу \"\(groupName)\" в приложении BandSync.\n\nИспользуйте код: \(code)\n\nСкачайте приложение BandSync для присоединения."
        
        // Создаем массив для шеринга, включая текст и QR-код, если он есть
        var itemsToShare: [Any] = [shareText]
        if let qrImage = qrCode {
            itemsToShare.append(qrImage)
        }
        
        // Показываем стандартный интерфейс шеринга iOS
        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
} else {
                            ProgressView()
                                .frame(width: 200, height: 200)
                        }
                        
                        if let code = groupService.group?.code {
                            Text("Код: \(code)")
                                .font(.system(.title3, design: .monospaced))
                                .bold()
                            
                            Button(action: {
                                UIPasteboard.general.string = code
                                alertMessage = "Код скопирован в буфер обмена"
                                showAlert = true
                            }) {
                                Label("Копировать код", systemImage: "doc.on.doc")
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Divider()
                    
                    // Секция приглашения по email
                    VStack(spacing: 15) {
                        Text("Пригласить по Email")
                            .font(.headline)
                        
                        TextField("Email пользователя", text: $inviteEmail)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        Button("Отправить приглашение") {
                            sendInvite()
                        }
                        .disabled(inviteEmail.isEmpty || isLoading)
                        .padding()
                        .background(inviteEmail.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        if !message.isEmpty {
                            Text(message)
                                .foregroundColor(message.contains("Ошибка") ? .red : .green)
                                .multilineTextAlignment(.center)
                                .padding()
                        }