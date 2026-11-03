import SwiftUI
import UIKit

// MARK: - 新建 / 重命名

struct PromptSheet: View {

    let kind: PromptKind

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @FocusState private var focused: Bool

    init(kind: PromptKind) {
        self.kind = kind
        _text = State(initialValue: kind.initialText)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kind.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)

            TextField(kind.placeholder, text: $text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.veil(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
                .onSubmit { submit() }

            HStack(spacing: 10) {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.veil(0.06)))
                }
                .buttonStyle(.plain)

                Button {
                    submit()
                } label: {
                    Text("确定")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(trimmed.isEmpty ? Theme.textTertiary : Theme.inverse)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(trimmed.isEmpty ? Theme.veil(0.08) : Theme.text))
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.elevated)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        app.performPrompt(kind, text: trimmed)
        dismiss()
    }
}

// MARK: - 系统分享面板

struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.view.tintColor = UIColor(Theme.accent)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
