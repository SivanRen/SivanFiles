import SwiftUI

// MARK: - 异步缩略图

struct FileThumbnail: View {
    let item: FileItem
    var size: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        IconTile(
            symbol: FileKind.symbol(for: item.kind, url: item.url),
            tint: FileKind.tint(for: item.kind),
            size: size,
            radius: max(8, size * 0.24),
            image: image
        )
        .task(id: item.url) {
            guard !item.isDirectory else { return }
            let loaded = await ThumbnailService.shared.thumbnail(for: item.url, size: size)
            if let loaded { image = loaded }
        }
    }
}

// MARK: - 选择圆圈

struct SelectCircle: View {
    let isOn: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isOn ? Theme.accent : Color.clear)
            Circle()
                .strokeBorder(isOn ? Theme.accent : Theme.strokeStrong, lineWidth: 1.5)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - 列表行

struct FileRow: View {

    let item: FileItem
    let isSelected: Bool
    let isEditing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                SelectCircle(isOn: isSelected)
                    .transition(.scale.combined(with: .opacity))
            }

            FileThumbnail(item: item, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 5) {
                    if item.isDirectory {
                        Text("文件夹")
                    } else {
                        Text(item.extLabel)
                        Text("·")
                        Text(Fmt.size(item.size))
                    }
                    Text("·")
                    Text(Fmt.shortDate(item.modified))
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Theme.accentSoft : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 网格单元

struct FileGridCell: View {

    let item: FileItem
    let isSelected: Bool
    let isEditing: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                FileThumbnail(item: item, size: 66)
                    .frame(maxWidth: .infinity)

                if isEditing {
                    SelectCircle(isOn: isSelected)
                        .offset(x: -2, y: -2)
                }
            }
            .frame(height: 70)

            Text(item.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30, alignment: .top)

            Text(item.isDirectory ? "文件夹" : Fmt.size(item.size))
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.accentSoft : Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
