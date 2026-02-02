import SwiftUI

struct BackgroundGridView: View {
    @ObservedObject var model: DocumentModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(BackgroundStyle.allBackgrounds) { style in
                BackgroundThumbnailView(
                    style: style,
                    image: model.quantizedImage ?? model.sourceImage,
                    isSelected: model.selectedBackground == style
                )
                .onTapGesture {
                    model.selectedBackground = style
                }
            }
        }
    }
}

struct BackgroundThumbnailView: View {
    let style: BackgroundStyle
    let image: NSImage?
    let isSelected: Bool

    var body: some View {
        ZStack {
            backgroundView(for: style)
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
            }
        }
        .frame(minWidth: 30, minHeight: 30)
        .aspectRatio(1.3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func backgroundView(for style: BackgroundStyle) -> some View {
        switch style {
        case .checkerboard:
            CheckerboardSwiftUIView()
        case .color(let r, let g, let b):
            Color(nsColor: NSColor(srgbRed: r, green: g, blue: b, alpha: 1))
        case .texture(let name, let ext):
            if let path = Bundle.main.path(forResource: "textures/\(name)", ofType: ext),
               let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
            } else {
                Color.gray
            }
        }
    }
}

struct CheckerboardSwiftUIView: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 6
            let cols = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.86)))
            for row in 0..<rows {
                for col in 0..<cols {
                    if (row + col) % 2 == 0 {
                        let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }
            }
        }
    }
}
