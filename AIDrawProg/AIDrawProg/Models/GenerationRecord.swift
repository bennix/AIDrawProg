import Foundation
import SwiftData

@Model
final class GenerationRecord {
    var createdAt: Date
    var modelName: String
    var language: String
    @Attribute(.externalStorage) var imageData: Data
    var responseText: String
    var flowchartData: Data?

    init(createdAt: Date = .now, modelName: String, language: String,
         imageData: Data, responseText: String, flowchartData: Data? = nil) {
        self.createdAt = createdAt
        self.modelName = modelName
        self.language = language
        self.imageData = imageData
        self.responseText = responseText
        self.flowchartData = flowchartData
    }
}
