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
    let image: CGImage

    private var redoStack: [Annotation] = []
    private var stepCounter: Int = 0

    init(image: CGImage) {
        self.image = image
    }

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Human label for what the next undo/redo will affect, e.g. "Arrow", "Rectangle".
    var undoLabel: String? { annotations.last.map(Self.label(for:)) }
    var redoLabel: String? { redoStack.last.map(Self.label(for:)) }

    func append(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        objectWillChange.send()
    }

    func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
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
