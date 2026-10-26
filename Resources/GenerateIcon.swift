import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let outer = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 205, yRadius: 205)
NSColor(red: 0.23, green: 0.36, blue: 0.29, alpha: 1).setFill(); outer.fill()
let cards: [(NSRect, NSColor)] = [
    (NSRect(x: 195, y: 525, width: 292, height: 292), NSColor(red: 0.87, green: 0.92, blue: 0.82, alpha: 1)),
    (NSRect(x: 525, y: 525, width: 292, height: 292), NSColor(red: 0.87, green: 0.93, blue: 0.97, alpha: 1)),
    (NSRect(x: 195, y: 195, width: 292, height: 292), NSColor(red: 0.97, green: 0.91, blue: 0.77, alpha: 1)),
    (NSRect(x: 525, y: 195, width: 292, height: 292), NSColor(red: 0.98, green: 0.87, blue: 0.80, alpha: 1))
]
for (rect, color) in cards { color.setFill(); NSBezierPath(roundedRect: rect, xRadius: 57, yRadius: 57).fill() }
for (index, symbol) in ["folder.fill", "square.grid.2x2.fill", "sun.max.fill", "text.alignleft"].enumerated() {
    let config = NSImage.SymbolConfiguration(pointSize: 110, weight: .regular)
    if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let rect = cards[index].0
        let iconSize = icon.size
        let scale = min(136 / iconSize.width, 136 / iconSize.height)
        let target = NSRect(x: rect.midX - iconSize.width * scale / 2, y: rect.midY - iconSize.height * scale / 2, width: iconSize.width * scale, height: iconSize.height * scale)
        NSColor(red: 0.26, green: 0.39, blue: 0.31, alpha: 1).set()
        icon.draw(in: target)
    }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
