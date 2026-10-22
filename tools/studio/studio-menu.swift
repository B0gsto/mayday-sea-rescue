import ApplicationServices
import AppKit
// Press a menu-bar item of ONE Studio process by pid, without focus or keystrokes.
// usage: studio-menu <pid> <menu> [<item>]   (no item: list the menu's item titles)
// Exit: 0 pressed/listed, 1 item not found or press failed, 2 bad args / not a Studio process.
let args = CommandLine.arguments
guard args.count > 2, let pid = Int32(args[1]) else { print("usage: studio-menu <pid> <menu> [<item>]"); exit(2) }
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; AXUIElementCopyAttributeValue(e, a as CFString, &v); return v }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func title(_ e: AXUIElement) -> String { attr(e, kAXTitleAttribute) as? String ?? "" }
guard let app = NSRunningApplication(processIdentifier: pid), (app.localizedName ?? "").contains("Roblox") else {
    print("pid \(pid) is not a Roblox Studio process"); exit(2)
}
let ax = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(ax, 5.0)
guard let bar = attr(ax, kAXMenuBarAttribute) else { print("no menu bar"); exit(1) }
guard let menu = kids(bar as! AXUIElement).first(where: { title($0) == args[2] }) else { print("no menu \(args[2])"); exit(1) }
let items = kids(menu).flatMap(kids)  // AXMenuBarItem -> AXMenu -> AXMenuItem
if args.count == 3 { items.map(title).filter { !$0.isEmpty }.forEach { print($0) }; exit(0) }
guard let item = items.first(where: { title($0) == args[3] }) else { print("no item \(args[3])"); exit(1) }
if (attr(item, kAXEnabledAttribute) as? Bool) == false { print("item \(args[3]) is disabled"); exit(1) }
let r = AXUIElementPerformAction(item, kAXPressAction as CFString)
print("press \(args[3]) -> \(r.rawValue)")
exit(r == .success ? 0 : 1)
