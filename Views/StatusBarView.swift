import SwiftUI

struct StatusBarView: View {
    @ObservedObject var model: DocumentModel

    var body: some View {
        HStack(spacing: 8) {
            Text(model.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
}
