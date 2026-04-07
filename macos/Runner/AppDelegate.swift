import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?
  private let menuBarModeKey = "menuBarMode"

  var isMenuBarMode: Bool {
    return UserDefaults.standard.bool(forKey: menuBarModeKey)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !isMenuBarMode
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if isMenuBarMode {
      applyMenuBarMode(enabled: true)
    }
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      showWindow()
    }
    return true
  }

  // MARK: - Menu Bar Mode

  func applyMenuBarMode(enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: menuBarModeKey)

    if enabled {
      createStatusItem()
      // Hide from dock
      DispatchQueue.main.async {
        NSApp.setActivationPolicy(.accessory)
        // Re-activate so the window stays visible during the switch
        NSApp.activate(ignoringOtherApps: true)
      }
    } else {
      removeStatusItem()
      // Show in dock
      DispatchQueue.main.async {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
  }

  // MARK: - NSStatusItem

  private func createStatusItem() {
    guard statusItem == nil else { return }

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem?.button {
      if #available(macOS 11.0, *),
         let base = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Protonify") {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        button.image = image
      } else {
        button.title = "P"
      }
      button.action = #selector(statusItemClicked(_:))
      button.target = self
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
  }

  private func removeStatusItem() {
    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }

    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      toggleWindow()
    }
  }

  private func toggleWindow() {
    guard let window = flutterWindow else { return }

    if window.isVisible && window.isKeyWindow {
      window.orderOut(nil)
    } else {
      showWindow()
    }
  }

  private func showWindow() {
    guard let window = self.flutterWindow else { return }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func showContextMenu() {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Show Protonify", action: #selector(showMenuAction), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit Protonify", action: #selector(quitMenuAction), keyEquivalent: "q"))
    statusItem?.menu = menu
    statusItem?.button?.performClick(nil)
    // Clear menu so left-click works again
    statusItem?.menu = nil
  }

  @objc private func showMenuAction() {
    showWindow()
  }

  @objc private func quitMenuAction() {
    NSApp.terminate(nil)
  }

  // MARK: - Window reference

  private var flutterWindow: NSWindow? {
    return NSApp.windows.first { $0 is MainFlutterWindow }
  }
}
