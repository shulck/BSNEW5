//
//  SetlistPDFExporter.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  SetlistPDFExporter.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import PDFKit
import UIKit

final class SetlistPDFExporter {
    static func export(setlist: Setlist) -> Data? {
        let pdf = PDFDocument()
        let page = PDFPage()
        
        let content = NSMutableAttributedString()

        let title = NSAttributedString(
            string: "\(setlist.name)\n\n",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 20)]
        )
        content.append(title)

        for (index, song) in setlist.songs.enumerated() {
            let line = "\(index + 1). \(song.title)  • \(song.formattedDuration)  • BPM: \(song.bpm)\n"
            content.append(NSAttributedString(string: line))
        }

        content.append(NSAttributedString(string: "\nTotal: \(setlist.formattedTotalDuration)"))

        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // A4
        let renderer = UIGraphicsImageRenderer(bounds: pageBounds)
        let image = renderer.image { _ in
            content.draw(in: CGRect(x: 40, y: 40, width: pageBounds.width - 80, height: pageBounds.height - 80))
        }

        if let page = PDFPage(image: image) {
            pdf.insert(page, at: 0)
            return pdf.dataRepresentation()
        }

        return nil
    }
}
