import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var lastMouseDownEvent: NSEvent?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    WindowApiSetup.setUp(
      binaryMessenger: flutterViewController.engine.binaryMessenger,
      api: self
    )

    super.awakeFromNib()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown {
      lastMouseDownEvent = event
    }
    super.sendEvent(event)
  }
}

extension MainFlutterWindow: WindowApi {
  func startDrag() throws {
    guard let event = lastMouseDownEvent else { return }
    performDrag(with: event)
  }

  func setMenuBarMode(enabled: Bool) throws {
    guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
    appDelegate.applyMenuBarMode(enabled: enabled)
  }

  func getMenuBarMode() throws -> Bool {
    guard let appDelegate = NSApp.delegate as? AppDelegate else { return false }
    return appDelegate.isMenuBarMode
  }
}
