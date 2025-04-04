//
//  MerchImageManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation
import UIKit
import FirebaseStorage

class MerchImageManager {
    static let shared = MerchImageManager()

    private init() {}

    func uploadImage(_ image: UIImage, for merchItem: MerchItem, completion: @escaping (Result<URL, Error>) -> Void) {
        // Image upload logic
        // For example, via Firebase Storage
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(.failure(NSError(domain: "ImageUploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image"])))
            return
        }

        let imageName = "\(UUID().uuidString).jpg"
        let imageRef = Storage.storage().reference().child("merch_images/\(imageName)")

        imageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let url = url {
                    completion(.success(url))
                } else {
                    completion(.failure(NSError(domain: "ImageUploadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get image URL"])))
                }
            }
        }
    }

    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let data = data,
                let image = UIImage(data: data)
            else {
                completion(nil)
                return
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}