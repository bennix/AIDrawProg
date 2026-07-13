//
//  Item.swift
//  AIDrawProg
//
//  Created by Nelle Rtcai on 7/14/26.
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
