import SwiftUI

struct DocumentContentView: View {
    var model: DocumentModel
    /// Dropped files, and whether they're temporary copies of promised files.
    var onDrop: (([URL], Bool) -> Void)?

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
