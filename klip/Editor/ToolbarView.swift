import SwiftUI
import AppKit

struct ToolbarView: View {
    @ObservedObject var state: EditorState
    let onSave: () -> Void
    let onCancel: () -> Void

    private let primaryTools: [(EditorTool, String)] = [
        (.select,    "arrow.up.left"),
        (.arrow,     "arrow.up.right"),
        (.rectangle, "rectangle"),
        (.ellipse,   "circle"),
        (.line,      "line.diagonal"),
        (.pen,       "scribble"),
        (.text,      "textformat"),
        (.highlight, "highlighter"),
        (.blur,      "drop"),
        (.step,      "1.circle.fill"),
        (.crop,      "crop"),
    ]

    private let swatches: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .black, .white
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(primaryTools, id: \.0) { tool, symbol in
                    toolButton(tool: tool, symbol: symbol)
                }
                Divider().frame(height: 22)
                HStack(spacing: 4) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, c in
                        Circle()
                            .fill(Color(nsColor: c))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.white, lineWidth: c == state.color ? 2 : 0))
                            .onTapGesture { state.color = c }
                    }
                }
                Divider().frame(height: 22)
                Slider(value: $state.width, in: 1...20, step: 1)
                    .frame(width: 80)
                Text("\(Int(state.width))px")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(VisualBlur(material: .hudWindow))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func toolButton(tool: EditorTool, symbol: String) -> some View {
        let active = state.tool == tool
        Button { state.tool = tool } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(active ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(active ? Color(red: 0.37, green: 0.36, blue: 0.90) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct VisualBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.state = .active
        v.blendingMode = .behindWindow
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
