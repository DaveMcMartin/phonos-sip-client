import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // Set initial window size (width: 500, height: 800) to ensure dialpad fits
    var windowFrame = self.frame
    windowFrame.size.width = 500
    windowFrame.size.height = 800
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
