// Real input + window lookup for the Roblox player app (com.roblox.RobloxPlayer). Built by rbx.py.
// usage: rbxin win | act | mv X Y | md X Y l|r | mu X Y l|r | dr X Y l|r | sc N
import Cocoa
let a = CommandLine.arguments
let src = CGEventSource(stateID: .hidSystemState)
func pt() -> CGPoint { CGPoint(x: Double(a[2])!, y: Double(a[3])!) }
func btn() -> CGMouseButton { a.count > 4 && a[4] == "r" ? .right : .left }
func post(_ e: CGEvent?) { e?.post(tap: ProcessInfo.processInfo.environment["RBX_TAP"] == "session" ? .cgSessionEventTap : .cghidEventTap) }
switch a[1] {
case "win":
  let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
  var best: (Int, CGRect)? = nil
  for w in list where (w[kCGWindowOwnerName as String] as? String) == "Roblox" && (w[kCGWindowLayer as String] as? Int) == 0 {
    let r = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! CFDictionary)!
    if best == nil || r.width * r.height > best!.1.width * best!.1.height { best = (w[kCGWindowNumber as String] as! Int, r) }
  }
  if let b = best { print(b.0, Int(b.1.minX), Int(b.1.minY), Int(b.1.width), Int(b.1.height)) } else { exit(1) }
case "act":
  NSRunningApplication.runningApplications(withBundleIdentifier: "com.roblox.RobloxPlayer").first?.activate(options: [.activateAllWindows])
  usleep(300_000)
  exit(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.roblox.RobloxPlayer" ? 0 : 3)
case "mv": post(CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: pt(), mouseButton: .left))
case "md": post(CGEvent(mouseEventSource: src, mouseType: btn() == .right ? .rightMouseDown : .leftMouseDown, mouseCursorPosition: pt(), mouseButton: btn()))
case "mu": post(CGEvent(mouseEventSource: src, mouseType: btn() == .right ? .rightMouseUp : .leftMouseUp, mouseCursorPosition: pt(), mouseButton: btn()))
case "dr": post(CGEvent(mouseEventSource: src, mouseType: btn() == .right ? .rightMouseDragged : .leftMouseDragged, mouseCursorPosition: pt(), mouseButton: btn()))
case "sc": post(CGEvent(scrollWheelEvent2Source: src, units: .line, wheelCount: 1, wheel1: Int32(a[2])!, wheel2: 0, wheel3: 0))
default: exit(2)
}
