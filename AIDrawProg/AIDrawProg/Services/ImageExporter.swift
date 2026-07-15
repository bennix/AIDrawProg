import UIKit
import PencilKit

enum ImageExporter {
    private static let maximumJPEGBytes = 900_000
    private static let minimumExportSide: CGFloat = 160

    /// 仅导出实际笔迹附近的区域，避免无限画布把空白区域一并发送给 AI。
    static func exportBounds(contentBounds: CGRect, canvasBounds: CGRect) -> CGRect? {
        guard !contentBounds.isNull, !contentBounds.isEmpty,
              canvasBounds.width > 0, canvasBounds.height > 0 else { return nil }

        let padding = max(32, max(contentBounds.width, contentBounds.height) * 0.08)
        var result = contentBounds.insetBy(dx: -padding, dy: -padding)
        if result.width < minimumExportSide {
            result = result.insetBy(dx: (minimumExportSide - result.width) / -2, dy: 0)
        }
        if result.height < minimumExportSide {
            result = result.insetBy(dx: 0, dy: (minimumExportSide - result.height) / -2)
        }
        let clipped = result.intersection(canvasBounds)
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }

    /// 把笔迹区域渲染为白底 JPEG。最长边和 JPEG 数据大小均受限，返回 base64 字符串。
    /// 画布为空时返回 nil（调用方应先用 drawing.strokes.isEmpty 拦截）。
    static func jpegBase64(from drawing: PKDrawing, canvasBounds: CGRect) -> String? {
        guard !drawing.strokes.isEmpty,
              let bounds = exportBounds(contentBounds: drawing.bounds, canvasBounds: canvasBounds)
        else { return nil }

        let imageLimits: [CGFloat] = [1536, 1280, 1024, 768, 640]
        let qualities: [CGFloat] = [0.78, 0.65, 0.5, 0.38]
        for longestSide in imageLimits {
            let image = render(drawing: drawing, bounds: bounds, longestSide: longestSide)
            for quality in qualities {
                if let data = image.jpegData(compressionQuality: quality), data.count <= maximumJPEGBytes {
                    return data.base64EncodedString()
                }
            }
        }
        return nil
    }

    private static func render(drawing: PKDrawing, bounds: CGRect, longestSide: CGFloat) -> UIImage {
        let longest = max(bounds.width, bounds.height)
        let renderScale = min(2, longestSide / max(longest, 1))
        let targetSize = CGSize(width: max(1, bounds.width * renderScale),
                                height: max(1, bounds.height * renderScale))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            drawing.image(from: bounds, scale: renderScale)
                .draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
