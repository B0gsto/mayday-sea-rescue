import ApplicationServices
import AppKit
// Press a menu-bar item of ONE Studio process by pid, without focus or keystrokes.
// usage: studio-menu <pid> <menu> [<item>]   (no item: list the menu's item titles)
// Exit: 0 pressed/listed, 1 item not found or press failed, 2 bad args / not a Studio process, 3 item disabled.
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
func items() -> [AXUIElement] { kids(menu).flatMap(kids) }  // AXMenuBarItem -> AXMenu -> AXMenuItem
func enabled(_ e: AXUIElement) -> Bool { (attr(e, kAXEnabledAttribute) as? Bool) != false }
if args.count == 3 {
    items().filter { !title($0).isEmpty }.forEach { print(title($0) + (enabled($0) ? "" : "  (disabled)")) }; exit(0)
}
guard var item = items().first(where: { title($0) == args[3] }) else { print("no item \(args[3])"); exit(1) }
// Startup modals (an untitled AXDialog) disable every File item: "Auto Recovery File Found" -> Ignore
let dismiss: Set<String> = ["Ignore"]
func button(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if (attr(e, kAXRoleAttribute) as? String) == "AXButton" && dismiss.contains(title(e)) { return e }
    if d > 12 { return nil }
    for k in kids(e) { if let b = button(k, d + 1) { return b } }
    return nil
}
if !enabled(item) {
    for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] where (attr(w, kAXSubroleAttribute) as? String) == "AXDialog" {
        if let b = button(w, 0) { print("dialog: press \(title(b)) -> \(AXUIElementPerformAction(b, kAXPressAction as CFString).rawValue)") }
    }
    app.activate()  // and let the window become active before re-checking
    Thread.sleep(forTimeInterval: 3)
    item = items().first(where: { title($0) == args[3] }) ?? item
    if !enabled(item) { print("item \(args[3]) is disabled"); exit(3) }
}
let r = AXUIElementPerformAction(item, kAXPressAction as CFString)
print("press \(args[3]) -> \(r.rawValue)")
exit(r == .success ? 0 : 1)
