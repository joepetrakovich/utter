//
//  Transcription.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/25.
//

import Foundation
import SwiftData

@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var text: String
    
    init(id: UUID = .init(), timestamp: Date, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}
