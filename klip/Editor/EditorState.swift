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
}
