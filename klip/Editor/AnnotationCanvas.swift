import AppKit
import Combine

final class AnnotationCanvas: NSView {
    let state: EditorState
    private var dragStart: CGPoint?
    private var liveAnnotation: Annotation?
    private var liveCropRect: CGRect?
    private var penPoints: [CGPoint] = []
    private var cancellable: AnyCancellable?

    init(state: EditorState) {
        self.state = state
        super.init(frame: NSRect(x: 0, y: 0, width: state.image.width, height: state.image.height))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        cancellable = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override var intrinsicContentSize: NSSize {
        NSSize(width: state.image.width, height: state.image.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.draw(state.image, in: bounds)
        for ann in state.annotations { ann.draw(in: ctx) }
        if let live = liveAnnotation { live.draw(in: ctx) }

        // Committed crop — dim everything outside the crop rect
        if let crop = state.cropRect {
            drawCropDim(crop, in: ctx)
        }
        // Live crop preview while dragging
        if let live = liveCropRect {
            drawCropDim(live, in: ctx)
        }
    }

    private func drawCropDim(_ rect: CGRect, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        // Fill the outer area as 4 strips (top, bottom, left, right)
        let b = bounds
        ctx.fill(CGRect(x: b.minX, y: rect.maxY, width: b.width, height: b.maxY - rect.maxY))
        ctx.fill(CGRect(x: b.minX, y: b.minY, width: b.width, height: rect.minY - b.minY))
        ctx.fill(CGRect(x: b.minX, y: rect.minY, width: rect.minX - b.minX, height: rect.height))
        ctx.fill(CGRect(x: rect.maxX, y: rect.minY, width: b.maxX - rect.maxX, height: rect.height))
        // Inner border
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        ctx.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        dragStart = p
        switch state.tool {
        case .pen:
            penPoints = [p]
            liveAnnotation = PenAnnotation(points: penPoints, color: state.color, width: state.width)
        case .step:
            let ann = StepAnnotation(center: p, color: state.color, number: state.nextStepNumber())
            state.append(ann)
            needsDisplay = true
        case .text:
            promptTextThenAppend(at: p)
        default: break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let start = dragStart else { return }
        let r = rect(start, p)
        switch state.tool {
        case .arrow:
            liveAnnotation = ArrowAnnotation(start: start, end: p, color: state.color, width: state.width)
        case .line:
            liveAnnotation = LineAnnotation(start: start, end: p, color: state.color, width: state.width)
        case .rectangle:
            liveAnnotation = RectAnnotation(rect: r, color: state.color, width: state.width)
        case .ellipse:
            liveAnnotation = EllipseAnnotation(rect: r, color: state.color, width: state.width)
        case .highlight:
            liveAnnotation = HighlightAnnotation(rect: r, color: state.color)
        case .blur:
            liveAnnotation = BlurAnnotation(rect: r, radius: 12)
        case .pen:
            penPoints.append(p)
            liveAnnotation = PenAnnotation(points: penPoints, color: state.color, width: state.width)
        case .crop:
            liveCropRect = r
        default: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let ann = liveAnnotation { state.append(ann) }
        if state.tool == .crop, let crop = liveCropRect, crop.width > 10, crop.height > 10 {
            // Clamp the crop to the canvas bounds
            let clamped = crop.intersection(bounds)
            state.setCropRect(clamped)
        }
        liveAnnotation = nil
        liveCropRect = nil
        dragStart = nil
        penPoints = []
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        if cmd && shift && event.charactersIgnoringModifiers?.lowercased() == "z" {
            state.redo()
        } else if cmd && event.charactersIgnoringModifiers?.lowercased() == "z" {
            state.undo()
        } else if event.keyCode == 51 {
            if state.canUndo { state.undo() }
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func promptTextThenAppend(at point: CGPoint) {
        let alert = NSAlert()
        alert.messageText = "Add text"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        field.placeholderString = "Annotation text"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            let ann = TextAnnotation(origin: point, text: field.stringValue, color: state.color, fontSize: 18)
            state.append(ann)
            needsDisplay = true
        }
    }
}
