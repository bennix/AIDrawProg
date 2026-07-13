import UIKit
import PencilKit

enum ImageExporter {
    /// 把画布内容渲染为白底 JPEG，最长边不超过 1568pt，返回 base64 字符串。
    /// 画布为空时返回 nil（调用方应先用 drawing.strokes.isEmpty 拦截）。
    static func jpegBase64(from drawing: PKDrawing, canvasBounds: CGRect) -> String? {
        guard !drawing.strokes.isEmpty,
              canvasBounds.width > 0, canvasBounds.height > 0 else { return nil }
        let source = drawing.image(from: canvasBounds, scale: 2)

        let maxSide: CGFloat = 1568
        let longest = max(source.size.width, source.size.height)
        let ratio = longest > maxSide ? maxSide / longest : 1
        let targetSize = CGSize(width: source.size.width * ratio,
                                height: source.size.height * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }
}
