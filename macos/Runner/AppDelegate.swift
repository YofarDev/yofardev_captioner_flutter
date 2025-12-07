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
        
        if let url = fileToOpen {
            methodChannel?.invokeMethod("setFilePath", arguments: url.path)
            fileToOpen = nil
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
