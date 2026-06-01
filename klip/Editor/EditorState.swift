import AppKit
import Combine

enum EditorTool {
    case select, arrow, rectangle, ellipse, line, pen, text, highlight, blur, step, crop
}

final class EditorState: ObservableObject {
    @Published var tool: EditorTool = .arrow
    @Published var color: NSColor = .systemRed
    @Published var width: CGFloat = 3
    @Published private(set) var annotations: [Annotation] = []
    @Published private(set) var cropRect: CGRect?
    let image: CGImage

    // Unified operation log so crop and annotation undos interleave correctly.
    private enum Op {
        case annotation(Annotation)
        case crop(previous: CGRect?, new: CGRect?)
    }
    private var history: [Op] = []
    private var redoStack: [Op] = []
    private var stepCounter: Int = 0

    init(image: CGImage) {
        self.image = image
    }

    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var undoLabel: String? {
        guard let last = history.last else { return nil }
        switch last {
        case .annotation(let a): return Self.label(for: a)
        case .crop:              return "Crop"
        }
    }

    var redoLabel: String? {
        guard let last = redoStack.last else { return nil }
        switch last {
        case .annotation(let a): return Self.label(for: a)
        case .crop:              return "Crop"
        }
    }

    func append(_ annotation: Annotation) {
        annotations.append(annotation)
        history.append(.annotation(annotation))
        redoStack.removeAll()
    }

    func setCropRect(_ rect: CGRect?) {
        let previous = cropRect
        cropRect = rect
        history.append(.crop(previous: previous, new: rect))
        redoStack.removeAll()
    }

    func undo() {
        guard let op = history.popLast() else { return }
        switch op {
        case .annotation(let a):
            if let idx = annotations.lastIndex(where: { $0 === a }) {
                annotations.remove(at: idx)
            }
        case .crop(let previous, _):
            cropRect = previous
        }
        redoStack.append(op)
        objectWillChange.send()
    }

    func redo() {
        guard let op = redoStack.popLast() else { return }
        switch op {
        case .annotation(let a):
            annotations.append(a)
        case .crop(_, let new):
            cropRect = new
        }
        history.append(op)
        objectWillChange.send()
    }

    func nextStepNumber() -> Int {
        stepCounter += 1
        return stepCounter
    }

    private static func label(for annotation: Annotation) -> String {
        switch annotation {
        case is ArrowAnnotation:     return "Arrow"
        case is RectAnnotation:      return "Rectangle"
        case is EllipseAnnotation:   return "Ellipse"
        case is LineAnnotation:      return "Line"
        case is PenAnnotation:       return "Pen Stroke"
        case is TextAnnotation:      return "Text"
        case is HighlightAnnotation: return "Highlight"
        case is BlurAnnotation:      return "Blur"
        case is StepAnnotation:      return "Step"
        default:                     return "Edit"
        }
    }
}
