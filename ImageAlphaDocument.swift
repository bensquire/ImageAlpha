import AppKit
import SwiftUI

class ImageAlphaDocument: NSDocument {

    let model = DocumentModel()
    private var pendingURL: URL?

    override class var autosavesInPlace: Bool { false }

    override func read(from url: URL, ofType typeName: String) throws {
        pendingURL = url
    }

    override func makeWindowControllers() {
        if let url = pendingURL {
            model.loadImage(from: url)
            pendingURL = nil
        }

        let contentView = DocumentContentView(model: model) { [weak self] urls in
            guard let self = self, let url = urls.first else { return }
            self.loadFromURL(url)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("ImageAlphaDocument")
        window.title = fileURL?.lastPathComponent ?? "ImageAlpha"
        window.minSize = NSSize(width: 500, height: 400)

        let controller = NSWindowController(window: window)
        addWindowController(controller)
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        return ["public.png"]
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = model.quantizedPNGData else {
            throw NSError(domain: NSOSStatusErrorDomain, code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No quantized image data available"
            ])
        }
        return data
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        return true
    }

    override func save(_ sender: Any?) {
        // "Save" overwrites the original — confirm first
        guard let url = fileURL, let window = windowControllers.first?.window else {
            saveAs(sender)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Overwrite original file?"
        alert.informativeText = "This will replace \"\(url.lastPathComponent)\" with the quantized image. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Save As\u{2026}")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                self.performSave()
            case .alertSecondButtonReturn:
                self.saveAs(sender)
            default:
                break
            }
        }
    }

    private func performSave() {
        guard let url = fileURL, let typeName = fileType else { return }
        save(to: url, ofType: typeName, for: .saveOperation) { error in
            if let error = error {
                NSApp.presentError(error)
            }
        }
    }

    private func loadFromURL(_ url: URL) {
        model.loadImage(from: url)
        fileURL = url
        fileType = "public.png"
        if let wc = windowControllers.first {
            wc.window?.title = url.lastPathComponent
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        if model.sourceImage == nil {
            if action == #selector(NSDocument.save(_:)) ||
               action == #selector(NSDocument.saveAs(_:)) {
                return false
            }
        }
        return super.validateMenuItem(menuItem)
    }
}
