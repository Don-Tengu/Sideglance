import AppKit

let size = 1024
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let canvas = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                       space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: Int, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

let tile = CGPath(roundedRect: CGRect(x: 96, y: 96, width: 832, height: 832),
                  cornerWidth: 185, cornerHeight: 185, transform: nil)
canvas.saveGState()
canvas.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x061816, alpha: 0.50))
canvas.setFillColor(color(0x102E29))
canvas.addPath(tile)
canvas.fillPath()
canvas.restoreGState()

canvas.saveGState()
canvas.addPath(tile)
canvas.clip()
let gradient = CGGradient(colorsSpace: colorSpace, colors: [color(0x2E6758), color(0x10221F)] as CFArray,
                          locations: [0, 1])!
canvas.drawLinearGradient(gradient, start: CGPoint(x: 210, y: 945), end: CGPoint(x: 780, y: 90), options: [])
canvas.restoreGState()
canvas.addPath(tile)
canvas.setStrokeColor(color(0xBFFCE1, alpha: 0.24))
canvas.setLineWidth(4)
canvas.strokePath()

let brackets = CGMutablePath()
for (x, y, dx, dy) in [(288.0, 736.0, 1.0, -1.0), (736, 736, -1, -1),
                       (288, 288, 1, 1), (736, 288, -1, 1)] {
    brackets.move(to: CGPoint(x: x, y: y + 115 * dy))
    brackets.addQuadCurve(to: CGPoint(x: x + 63 * dx, y: y), control: CGPoint(x: x, y: y))
    brackets.addLine(to: CGPoint(x: x + 115 * dx, y: y))
}
canvas.addPath(brackets)
canvas.setStrokeColor(color(0x9AF1CC))
canvas.setLineWidth(39)
canvas.setLineCap(.round)
canvas.strokePath()

canvas.setFillColor(color(0x0D2421))
canvas.fillEllipse(in: CGRect(x: 366, y: 366, width: 292, height: 292))
canvas.setStrokeColor(color(0x6CCFA9))
canvas.setLineWidth(21)
canvas.strokeEllipse(in: CGRect(x: 379, y: 379, width: 266, height: 266))
canvas.setFillColor(color(0x2E745F))
canvas.fillEllipse(in: CGRect(x: 433, y: 433, width: 158, height: 158))
canvas.setFillColor(color(0xBAF9DC))
canvas.fillEllipse(in: CGRect(x: 473, y: 505, width: 68, height: 68))

let rendered = canvas.makeImage()!

// ICNS stores each PNG in a FourCC chunk with a big-endian length, including its header.
func chunk(_ type: String, _ payload: Data) -> Data {
    var length = UInt32(payload.count + 8).bigEndian
    var data = Data(type.utf8)
    data.append(withUnsafeBytes(of: &length) { Data($0) })
    data.append(payload)
    return data
}

var icons = Data()
for (type, pixels) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256),
                       ("ic09", 512), ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)] {
    let output = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                           space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    output.interpolationQuality = .high
    output.draw(rendered, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let image = NSBitmapImageRep(cgImage: output.makeImage()!)
    icons.append(chunk(type, image.representation(using: .png, properties: [:])!))
}
try chunk("icns", icons).write(to: destination)
