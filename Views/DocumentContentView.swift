import SwiftUI

struct DocumentContentView: View {
    @ObservedObject var model: DocumentModel
    var onDrop: (([URL]) -> Void)?

    var body: some View {
        HSplitView {
            SidebarView(model: model)
                .frame(minWidth: 210, maxWidth: 300)

            ZStack(alignment: .bottom) {
                ImageCanvasView(model: model, onDrop: onDrop)

                StatusBarView(model: model)
            }
        }
    }
}
