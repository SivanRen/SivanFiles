import SwiftUI

struct InfoSheet: View {

    let item: FileItem

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [InfoRow] = []
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "简介")

            ScrollView {
                VStack(spacing: 18) {
                    header

                    PanelGroup("详细信息") {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            infoRow(row)
                            if index < rows.count - 1 {
                                Hairline().padding(.leading, 14)
                            }
                        }
                    }

                    actions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .task {
            rows = app.store.infoRows(for: item)
        }
        .confirmationDialog("确定删除这个项目？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("移到最近删除", role: .destructive) {
                app.moveToTrash([item.url])
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            FileThumbnail(item: item, size: 74)
            VStack(spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                Text(app.store.mimeDescription(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func infoRow(_ row: InfoRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.title)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(row.value)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionButton(icon: "square.and.arrow.up", title: "分享") {
                dismiss()
                app.share([item.url])
            }
            actionButton(icon: "doc.on.doc", title: "复制") {
                app.copy([item.url])
                dismiss()
            }
            actionButton(icon: "link", title: "复制路径") {
                PasteboardService.copyText(item.url.path)
                app.toast("路径已复制")
                dismiss()
            }
            actionButton(icon: "trash", title: "删除", danger: true) {
                confirmDelete = true
            }
        }
    }

    private func actionButton(icon: String, title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(danger ? Theme.danger : Theme.text)
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}
