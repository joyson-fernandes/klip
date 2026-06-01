import AppKit

protocol Annotation: AnyObject {
    func draw(in ctx: CGContext)
    var bounds: CGRect { get }
}

final class ArrowAnnotation: Annotation {
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var width: CGFloat

    init(start: CGPoint, end: CGPoint, color: NSColor, width: CGFloat) {
        self.start = start; self.end = end; self.color = color; self.width = width
    }

    var bounds: CGRect {
        let r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                       width: abs(end.x - start.x), height: abs(end.y - start.y))
        return r.insetBy(dx: -width, dy: -width)
    }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen: CGFloat = max(10, width * 3)
        let p1 = CGPoint(x: end.x - headLen * cos(angle - .pi / 6), y: end.y - headLen * sin(angle - .pi / 6))
        let p2 = CGPoint(x: end.x - headLen * cos(angle + .pi / 6), y: end.y - headLen * sin(angle + .pi / 6))
        ctx.move(to: end); ctx.addLine(to: p1); ctx.addLine(to: p2); ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }
}

final class RectAnnotation: Annotation {
    var rect: CGRect
    var color: NSColor
    var width: CGFloat

    init(rect: CGRect, color: NSColor, width: CGFloat) {
        self.rect = rect; self.color = color; self.width = width
    }

    var bounds: CGRect { rect.insetBy(dx: -width, dy: -width) }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.stroke(rect)
        ctx.restoreGState()
    }
}

final class EllipseAnnotation: Annotation {
    var rect: CGRect
    var color: NSColor
    var width: CGFloat

    init(rect: CGRect, color: NSColor, width: CGFloat) {
        self.rect = rect; self.color = color; self.width = width
    }

    var bounds: CGRect { rect.insetBy(dx: -width, dy: -width) }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }
}

final class LineAnnotation: Annotation {
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var width: CGFloat

    init(start: CGPoint, end: CGPoint, color: NSColor, width: CGFloat) {
        self.start = start; self.end = end; self.color = color; self.width = width
    }

    var bounds: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
            .insetBy(dx: -width, dy: -width)
    }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: start); ctx.addLine(to: end); ctx.strokePath()
        ctx.restoreGState()
    }
}

final class PenAnnotation: Annotation {
    var points: [CGPoint]
    var color: NSColor
    var width: CGFloat

    init(points: [CGPoint], color: NSColor, width: CGFloat) {
        self.points = points; self.color = color; self.width = width
    }

    var bounds: CGRect {
        guard !points.isEmpty else { return .zero }
        let xs = points.map(\.x), ys = points.map(\.y)
        let r = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        return r.insetBy(dx: -width, dy: -width)
    }

    func draw(in ctx: CGContext) {
        guard let first = points.first else { return }
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: first)
        for p in points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()
        ctx.restoreGState()
    }
}

final class TextAnnotation: Annotation {
    var origin: CGPoint
    var text: String
    var color: NSColor
    var fontSize: CGFloat

    init(origin: CGPoint, text: String, color: NSColor, fontSize: CGFloat) {
        self.origin = origin; self.text = text; self.color = color; self.fontSize = fontSize
    }

    var bounds: CGRect {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: fontSize)]
        let size = (text as NSString).size(withAttributes: attrs)
        return CGRect(origin: origin, size: size).insetBy(dx: -2, dy: -2)
    }

    func draw(in ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: color
        ]
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        (text as NSString).draw(at: origin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class HighlightAnnotation: Annotation {
    var rect: CGRect
    var color: NSColor

    init(rect: CGRect, color: NSColor) {
        self.rect = rect
        self.color = color.withAlphaComponent(0.35)
    }

    var bounds: CGRect { rect }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()
    }
}

final class BlurAnnotation: Annotation {
    var rect: CGRect
    var radius: CGFloat

    init(rect: CGRect, radius: CGFloat) {
        self.rect = rect; self.radius = radius
    }

    var bounds: CGRect { rect }

    func draw(in ctx: CGContext) {
        // v1.1: Placeholder dashed outline. True blur composition is deferred — would
        // require re-sampling the underlying bitmap via CIFilter. For now the user
        // sees the affected region marked as a dashed rect on save.
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.systemGray.cgColor)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.stroke(rect)
        ctx.restoreGState()
    }
}

final class StepAnnotation: Annotation {
    var center: CGPoint
    var color: NSColor
    var number: Int
    let radius: CGFloat = 14

    init(center: CGPoint, color: NSColor, number: Int) {
        self.center = center; self.color = color; self.number = number
    }

    var bounds: CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: bounds)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: "\(number)", attributes: attrs)
        let size = str.size()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        str.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }
}
