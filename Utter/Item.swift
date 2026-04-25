//
//  Item.swift
//  Utter
//
//  Created by Joe Petrakovich on 2026/04/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
