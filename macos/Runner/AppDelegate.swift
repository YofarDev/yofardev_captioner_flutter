import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var methodChannel: FlutterMethodChannel?
    var fileToOpen: URL?

    override func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            if methodChannel != nil {
                methodChannel?.invokeMethod("setFilePath", arguments: url.path)
            } else {
                fileToOpen = url
            }
        }
    }

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "dev.yofardev.io/open_file",
                                               binaryMessenger: controller.engine.binaryMessenger)

        // Set up method handler for setting window title
        methodChannel?.setMethodCallHandler({ [weak self] (call, result) in
            if call.method == "setFilePath" {
                if let url = call.arguments as? String {
                    self?.handleFileOpen(url: url)
                }
                result(nil)
            } else if call.method == "setWindowTitle" {
                if let title = call.arguments as? String {
                    self?.mainFlutterWindow?.title = title
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        if let url = fileToOpen {
            handleFileOpen(url: url.path)
            fileToOpen = nil
        }
    }

    private func handleFileOpen(url: String) {
        methodChannel?.invokeMethod("setFilePath", arguments: url)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
