import AppKit
import SwiftUI

class ImageAlphaDocument: NSDocument {

    let model = DocumentModel()
    private var optimizeWithImageOptimCheckbox: NSButton?

    override class var autosavesInPlace: Bool { false }

    /// Decodes here, so a file that isn't an image fails the open with an
    /// error NSDocument shows, instead of leaving an empty window. Reads run on
    /// the main thread while canConcurrentlyReadDocuments(ofType:) keeps its
    /// default of false. /documentation/appkit/nsdocument/canconcurrentlyreaddocuments(oftype:)
    override func read(from url: URL, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            try model.loadImage(from: url)
        }
    }

    override func makeWindowControllers() {
        model.didChangeParameters = { [weak self] in
            self?.updateChangeCount(.changeDone)
        }

        let contentView = DocumentContentView(model: model) { [weak self] urls, areCopies in
            self?.openDropped(urls, areCopies: areCopies)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        // No title here: addWindowController(_:) has the document fill it in,
        // proxy icon and all. /documentation/appkit/nsdocument/addwindowcontroller(_:)
        window.setFrameAutosaveName("ImageAlphaDocument")
        window.minSize = NSSize(width: 500, height: 400)

        let controller = NSWindowController(window: window)
        addWindowController(controller)
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        return ["public.png"]
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = model.quantizedPNGData else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.pornel.ImageOptim") != nil
        else {
            return true
        }

        let checkbox = NSButton(checkboxWithTitle: "Optimize with ImageOptim", target: nil, action: nil)
        checkbox.state = Preferences.optimizeWithImageOptim ? .on : .off
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 32))
        checkbox.frame = NSRect(x: 8, y: 4, width: 234, height: 24)
        accessory.addSubview(checkbox)
        savePanel.accessoryView = accessory
        optimizeWithImageOptimCheckbox = checkbox
        return true
    }

    /// Saving overwrites the original with the quantized image, so confirm
    /// first. Every save to the file comes through here: File → Save "merely
    /// invokes" this method, and so does Save in the close and quit sheets
    /// (NSDocument.h, saveDocument: and canCloseDocumentWithDelegate:).
    override func save(
        withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let url = fileURL else {
            // Untitled: NSDocument runs the Save panel, so nothing is overwritten.
            super.save(withDelegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Overwrite original file?"
        alert.informativeText =
            "This will replace \"\(url.lastPathComponent)\" with the quantized image. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Save As\u{2026}")
        alert.addButton(withTitle: "Cancel")

        let finish = { (response: NSApplication.ModalResponse) in
            self.continueSave(
                after: response, delegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
        }
        // "may be nil, in which case the sender should present an app-modal
        // panel." /documentation/appkit/nsdocument/windowforsheet
        if let window = windowForSheet {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(alert.runModal())
        }
    }

    /// Carries out the choice made in the overwrite alert. Whoever asked for
    /// the save hears the outcome either way, so a close or quit can go ahead
    /// or stop.
    func continueSave(
        after response: NSApplication.ModalResponse,
        delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?
    ) {
        switch response {
        case .alertFirstButtonReturn:
            // NSDocument's own save also checks whether another app has changed
            // the file. /documentation/appkit/nsdocument/save(withdelegate:didsave:contextinfo:)
            super.save(withDelegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
        case .alertSecondButtonReturn:
            runModalSavePanel(
                for: .saveAsOperation, delegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
        default:
            reportSave(false, to: delegate, selector: didSaveSelector, contextInfo: contextInfo)
        }
    }

    /// Sends the didSave callback NSDocument's save methods take, whose
    /// signature is document:didSave:contextInfo:.
    /// /documentation/appkit/nsdocument/runmodalsavepanel(for:delegate:didsave:contextinfo:)
    private func reportSave(
        _ didSave: Bool, to delegate: Any?, selector: Selector?, contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let delegate = delegate as? NSObject, let selector, delegate.responds(to: selector) else {
            return
        }
        typealias DidSave =
            @convention(c) (NSObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        let callback = unsafeBitCast(delegate.method(for: selector), to: DidSave.self)
        callback(delegate, selector, self, didSave, contextInfo)
    }

    override func save(
        to url: URL, ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Capture checkbox state before the panel closes
        let shouldOptimize = shouldOptimizeWithImageOptim()
        if let checkbox = optimizeWithImageOptimCheckbox {
            Preferences.optimizeWithImageOptim = checkbox.state == .on
            optimizeWithImageOptimCheckbox = nil
        }

        Task { @MainActor in
            // Saved files always get the maximum-effort encode, computed on
            // demand; previews may briefly show the fast encode's larger size.
            _ = await model.finalPNGData()
            super.save(to: url, ofType: typeName, for: saveOperation) { error in
                completionHandler(error)
                if error == nil {
                    self.model.noteSaved(to: url)
                    if shouldOptimize {
                        self.openInImageOptim(url: url)
                    }
                }
            }
        }
    }

    /// Dropped files open as documents of their own, as from the Finder, so
    /// each gets its real type and file coordination; fileURL is "only for
    /// recording the document's location during its initial opening or saving".
    /// /documentation/appkit/nsdocument/fileurl
    /// The empty untitled window that received the drop gives way to the first.
    /// A promised file, received into a temporary folder, opens untitled
    /// instead, so Save asks where to put it rather than offering to overwrite
    /// a copy nobody can see. /documentation/appkit/nsdocumentcontroller/duplicatedocument(withcontentsof:copying:displayname:)
    private func openDropped(_ urls: [URL], areCopies: Bool) {
        var replacesSelf = fileURL == nil
        let opened = { [weak self] (error: Error?) in
            if let error {
                NSDocumentController.shared.presentError(error)
            } else if replacesSelf {
                replacesSelf = false
                self?.close()
            }
        }
        for url in urls {
            if areCopies {
                do {
                    let name = url.deletingPathExtension().lastPathComponent
                    _ = try NSDocumentController.shared.duplicateDocument(
                        withContentsOf: url, copying: false, displayName: name)
                    opened(nil)
                } catch {
                    opened(error)
                }
            } else {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    opened(error)
                }
            }
        }
    }

    @objc func copy(_ sender: Any?) {
        guard let data = model.quantizedPNGData,
            let image = model.quantizedImage
        else {
            NSSound.beep()
            return
        }
        // A single pasteboard item carrying both representations; separate
        // items would let paste targets pick up the unquantized TIFF render.
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        if let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    private func shouldOptimizeWithImageOptim() -> Bool {
        if let checkbox = optimizeWithImageOptimCheckbox {
            return checkbox.state == .on
        }
        return Preferences.optimizeWithImageOptim
    }

    private func openInImageOptim(url: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.pornel.ImageOptim")
        else { return }
        NSWorkspace.shared.open(
            [url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        if action == #selector(ImageAlphaDocument.copy(_:)) {
            return model.quantizedPNGData != nil
        }
        if model.sourceImage == nil {
            if action == #selector(NSDocument.save(_:)) || action == #selector(NSDocument.saveAs(_:)) {
                return false
            }
        }
        return super.validateMenuItem(menuItem)
    }
}
