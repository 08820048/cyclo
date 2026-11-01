// Draws Cyclo's app icon: a viewfinder (four corner brackets) around a lit stage.
//
//   swift scripts/brand/make-icon.swift <output directory>
//   swift scripts/brand/make-icon.swift --preview <file.png>     the icon large and at small sizes
//
// The menu bar glyph in MenuBarController.swift is the same mark: brackets plus a centre
// rectangle that is outlined when idle and lit when the stage is up.
//
// Writes:
//   AppIcon-square-1024.png  1024x1024 full-bleed square, no rounded corners; macOS applies the mask itself. The .icns is made from this
//   AppIcon-1024.png         rounded with a shadow, for places that show it as a plain picture (website, README)
//   Logo.png                 256 px of the rounded one
//   AppIcon.icns
import AppKit
import SwiftUI

func hex(_ v: UInt32) -> Color {
    Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

struct Icon: View {
    var fullBleed = false
    let side: CGFloat = 824

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: fullBleed ? 0 : 184, style: .continuous)
        ZStack {
            tile.fill(Color.black).frame(width: side, height: side)
                .shadow(color: .black.opacity(fullBleed ? 0 : 0.35), radius: 22, y: 14)
            Canvas { ctx, size in
                let t = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
                ctx.clip(to: tile.path(in: t))
                ctx.translateBy(x: t.minX, y: t.minY)
                background(&ctx)

                // The lit stage in the middle.
                let stage = RoundedRectangle(cornerRadius: 46, style: .continuous).path(in: CGRect(x: 412 - 128, y: 412 - 84, width: 256, height: 168))
                var glow = ctx
                glow.addFilter(.blur(radius: 70))
                glow.fill(stage, with: .color(hex(0xFFB65C).opacity(0.75)))
                ctx.fill(stage, with: .linearGradient(Gradient(colors: [hex(0xFFF6E0), hex(0xFFD08A)]),
                                                      startPoint: CGPoint(x: 412, y: 328), endPoint: CGPoint(x: 412, y: 496)))
                var sheen = ctx
                sheen.clip(to: stage)
                sheen.fill(Path(CGRect(x: 0, y: 328, width: 824, height: 6)), with: .color(.white.opacity(0.9)))

                // The viewfinder brackets.
                let brackets = brackets(in: CGRect(x: 142, y: 182, width: 540, height: 460), arm: 128, radius: 78)
                let style = StrokeStyle(lineWidth: 50, lineCap: .round, lineJoin: .round)
                var halo = ctx
                halo.addFilter(.blur(radius: 40))
                halo.stroke(brackets, with: .color(hex(0x6C6CFF).opacity(0.5)), style: style)
                ctx.stroke(brackets, with: .linearGradient(Gradient(colors: [.white, hex(0xD3D6FF), hex(0x9A9DEF)]),
                                                           startPoint: CGPoint(x: 142, y: 182), endPoint: CGPoint(x: 682, y: 642)), style: style)

                // Rim light around the tile.
                ctx.stroke(tile.path(in: CGRect(x: 0, y: 0, width: side, height: side)), with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.22), .white.opacity(0.02), .white.opacity(0.06)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: side)), lineWidth: 4)
            }
            .frame(width: 1024, height: 1024)
        }
        .frame(width: 1024, height: 1024)
        .scaleEffect(fullBleed ? 1024 / side : 1)
    }

    func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 824, height: 824))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [hex(0x23243A), hex(0x09090F)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 824)))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [hex(0x5457FF).opacity(0.28), .clear]), center: CGPoint(x: 412, y: 0), startRadius: 0, endRadius: 600))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [hex(0xFFB65C).opacity(0.16), .clear]), center: CGPoint(x: 412, y: 412), startRadius: 0, endRadius: 360))
    }

    /// Four open corners of `r`: each is an arm, a rounded turn, an arm.
    func brackets(in r: CGRect, arm: CGFloat, radius: CGFloat) -> Path {
        var p = Path()
        for (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] {
            let cx = sx > 0 ? r.minX : r.maxX, cy = sy > 0 ? r.minY : r.maxY
            p.move(to: CGPoint(x: cx, y: cy + sy * arm))
            p.addLine(to: CGPoint(x: cx, y: cy + sy * radius))
            p.addQuadCurve(to: CGPoint(x: cx + sx * radius, y: cy), control: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: cx + sx * arm, y: cy))
        }
        return p
    }
}

struct Sheet: View {
    var body: some View {
        VStack(spacing: 20) {
            Icon().frame(width: 1024, height: 1024).scaleEffect(360 / 1024).frame(width: 360, height: 360)
            HStack(spacing: 20) {
                ForEach([128.0, 64.0, 32.0, 16.0], id: \.self) { px in
                    Icon().frame(width: 1024, height: 1024).scaleEffect(px / 1024).frame(width: px, height: px)
                }
            }
        }
        .padding(36)
        .background(Color(white: 0.93))
    }
}

@MainActor func png(_ view: some View, to url: URL) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    let rep = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func run(_ tool: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    try! p.run(); p.waitUntilExit()
}

@MainActor func main() {
    let args = CommandLine.arguments
    if args.count > 2, args[1] == "--preview" {
        png(Sheet(), to: URL(fileURLWithPath: args[2]))
        return
    }
    let out = URL(fileURLWithPath: args.count > 1 ? args[1] : ".", isDirectory: true)
    try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let rounded = out.appendingPathComponent("AppIcon-1024.png")
    let master = out.appendingPathComponent("AppIcon-square-1024.png")
    png(Icon(), to: rounded)
    png(Icon(fullBleed: true), to: master)
    run("/usr/bin/sips", ["-z", "256", "256", rounded.path, "--out", out.appendingPathComponent("Logo.png").path])

    let set = out.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    try? FileManager.default.removeItem(at: set)
    try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                       ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
        run("/usr/bin/sips", ["-z", "\(px)", "\(px)", master.path, "--out", set.appendingPathComponent("icon_\(name).png").path])
    }
    run("/usr/bin/iconutil", ["-c", "icns", set.path, "-o", out.appendingPathComponent("AppIcon.icns").path])
    try? FileManager.default.removeItem(at: set)
}
MainActor.assumeIsolated { main() }
