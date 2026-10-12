//
//  build.swift
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//
//  Bakes the 2.0 UI fonts (BMFont .fnt + PNG atlas) for every supported
//  screen size. Connect IQ has no heavy italic face and vívoactive 5 has no
//  scalable fonts at all, so the hero numbers are rasterised here instead:
//  Roboto Black, sheared for the italic, one set per display diameter.
//
//  Usage:  swift tools/numfont/build.swift [fontDir]
//  fontDir defaults to the Connect IQ SDK font folder, which ships
//  Roboto-Black.ttf (Apache-2.0). Nothing is downloaded.
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let defaultFontDir = NSHomeDirectory() + "/Library/Application Support/Garmin/ConnectIQ/Fonts"
let fontDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultFontDir

struct FontSpec {
    let id: String
    let file: String
    let size: Double        // in 1/200ths of the display diameter
    let shear: Double       // 0 = upright
    let tracking: Double    // extra advance, in em
    let chars: String
}

let digits = "0123456789:"
let signed = digits + "+-"
let upper = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:/+-'&%()!?#\u{00B7}\u{2665}"

// Display diameter → output folder. The base folder serves the 454 px
// devices (fr965, fenix847mm); the others override the same font ids.
let targets: [(dir: String, diameter: Double, capBoost: Double)] = [
    ("resources/fonts", 454, 1.0),
    ("resources-fr265/fonts", 416, 1.0),
    ("resources-vivoactive5/fonts", 390, 1.0),
    // 260 px MIP: captions drawn a touch larger so they stay legible.
    ("resources-fenix7/fonts", 260, 1.1),
]

func specs(capBoost: Double) -> [FontSpec] {
    return [
        FontSpec(id: "numHero", file: "Roboto-Black.ttf", size: 68, shear: 0.2, tracking: -0.02, chars: digits),
        FontSpec(id: "numHeroSm", file: "Roboto-Black.ttf", size: 54, shear: 0.2, tracking: -0.02, chars: digits),
        FontSpec(id: "numBig", file: "Roboto-Black.ttf", size: 34, shear: 0.2, tracking: -0.01, chars: signed),
        FontSpec(id: "numMid", file: "Roboto-Black.ttf", size: 25, shear: 0.2, tracking: 0.0, chars: signed),
        FontSpec(id: "txtTitle", file: "Roboto-Black.ttf", size: 14 * capBoost, shear: 0, tracking: 0.03, chars: upper),
        FontSpec(id: "txtCap", file: "Roboto-Black.ttf", size: 10.5 * capBoost, shear: 0, tracking: 0.14, chars: upper),
    ]
}

func loadFont(_ file: String, size: Double) -> CTFont {
    let url = URL(fileURLWithPath: fontDir + "/" + file)
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
          let desc = descs.first else {
        FileHandle.standardError.write("font not found: \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
    return CTFontCreateWithFontDescriptor(desc, CGFloat(size), nil)
}

// Heart drawn by hand — Roboto has no U+2665. Unit box, y up.
func heartPath(cap: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let w = cap * 1.05, h = cap * 0.96
    p.move(to: CGPoint(x: w * 0.5, y: 0))
    p.addCurve(to: CGPoint(x: 0, y: h * 0.68),
               control1: CGPoint(x: w * 0.18, y: h * 0.26), control2: CGPoint(x: 0, y: h * 0.44))
    p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.80),
               control1: CGPoint(x: 0, y: h * 1.06), control2: CGPoint(x: w * 0.40, y: h * 1.08))
    p.addCurve(to: CGPoint(x: w, y: h * 0.68),
               control1: CGPoint(x: w * 0.60, y: h * 1.08), control2: CGPoint(x: w, y: h * 1.06))
    p.addCurve(to: CGPoint(x: w * 0.5, y: 0),
               control1: CGPoint(x: w, y: h * 0.44), control2: CGPoint(x: w * 0.82, y: h * 0.26))
    p.closeSubpath()
    return p
}

struct Glyph {
    let code: UInt32
    let path: CGPath?
    let box: CGRect         // integer pixel box, y up, relative to the baseline origin
    let advance: Int
    var shift: CGFloat = 0  // horizontal shift applied to box (not to path)
    var atlasX = 0
    var atlasY = 0
}

func build(spec: FontSpec, diameter: Double, outDir: URL) {
    let px = (spec.size * diameter / 200).rounded()
    let font = loadFont(spec.file, size: px)
    let cap = CTFontGetCapHeight(font)
    let pad = ceil(px * 0.16)                       // room above caps / below baseline
    let lineHeight = Int(ceil(cap) + 2 * pad)
    let base = Int(pad + ceil(cap))

    var glyphs: [Glyph] = []
    for scalar in spec.chars.unicodeScalars {
        var path: CGPath?
        var advance: CGFloat = 0
        // Shear about mid cap-height so slanted text stays optically centred.
        var t = CGAffineTransform(a: 1, b: 0, c: CGFloat(spec.shear), d: 1,
                                  tx: -CGFloat(spec.shear) * cap / 2, ty: 0)
        if scalar.value == 0x2665 {
            let heart = heartPath(cap: cap)
            path = heart
            advance = heart.boundingBoxOfPath.width
        } else {
            // Number fonts: draw the real minus sign under the ASCII hyphen id.
            let source = (scalar == "-" && spec.shear > 0) ? "\u{2212}" : String(scalar)
            var chars = Array(source.utf16)
            var cg = [CGGlyph](repeating: 0, count: chars.count)
            guard CTFontGetGlyphsForCharacters(font, &chars, &cg, chars.count), cg[0] != 0 else {
                FileHandle.standardError.write("missing glyph U+\(String(scalar.value, radix: 16))\n".data(using: .utf8)!)
                exit(1)
            }
            var adv = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &cg, &adv, 1)
            advance = adv.width
            path = CTFontCreatePathForGlyph(font, cg[0], &t)
        }
        let adv = Int((advance + CGFloat(spec.tracking) * px).rounded())
        var box = CGRect.zero
        if let p = path, !p.isEmpty {
            let b = p.boundingBoxOfPath
            let x0 = floor(b.minX) - 1, y0 = floor(b.minY) - 1
            box = CGRect(x: x0, y: y0, width: ceil(b.maxX) + 1 - x0, height: ceil(b.maxY) + 1 - y0)
        }
        glyphs.append(Glyph(code: scalar.value, path: path, box: box, advance: adv))
    }

    // Connect IQ handles negative x offsets inconsistently — shift the whole
    // face right so the leftmost glyph starts at 0 (spacing is unchanged).
    let shift = -(glyphs.filter { $0.box.width > 0 }.map { $0.box.minX }.min() ?? 0)
    if shift > 0 {
        glyphs = glyphs.map {
            Glyph(code: $0.code, path: $0.path, box: $0.box.offsetBy(dx: shift, dy: 0),
                  advance: $0.advance, shift: shift)
        }
    }

    // Row packing into a power-of-two-wide atlas.
    let area = glyphs.reduce(0) { $0 + Int($1.box.width + 1) * Int($1.box.height + 1) }
    var atlasW = 128
    while atlasW * atlasW < area * 5 / 4 { atlasW *= 2 }
    var x = 0, y = 0, rowH = 0
    for i in glyphs.indices {
        let w = Int(glyphs[i].box.width), h = Int(glyphs[i].box.height)
        if w == 0 { continue }
        if x + w + 1 > atlasW { x = 0; y += rowH + 1; rowH = 0 }
        glyphs[i].atlasX = x
        glyphs[i].atlasY = y
        x += w + 1
        rowH = max(rowH, h)
    }
    let atlasH = max(4, (y + rowH + 3) / 4 * 4)

    let ctx = CGContext(data: nil, width: atlasW, height: atlasH, bitsPerComponent: 8,
                        bytesPerRow: atlasW * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    for g in glyphs {
        guard let p = g.path, g.box.width > 0 else { continue }
        ctx.saveGState()
        // Atlas rows are top-down; CoreGraphics is bottom-up.
        let bottom = CGFloat(atlasH - g.atlasY) - g.box.height
        ctx.translateBy(x: CGFloat(g.atlasX) - g.box.minX + g.shift, y: bottom - g.box.minY)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()
    }

    try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let png = outDir.appendingPathComponent("\(spec.id)_0.png")
    let dest = CGImageDestinationCreateWithURL(png as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)

    var out = "info face=\"\(spec.id)\" size=-\(Int(px)) bold=0 italic=\(spec.shear > 0 ? 1 : 0) charset=\"\" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0\n"
    out += "common lineHeight=\(lineHeight) base=\(base) scaleW=\(atlasW) scaleH=\(atlasH) pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4\n"
    out += "page id=0 file=\"\(spec.id)_0.png\"\n"
    out += "chars count=\(glyphs.count)\n"
    for g in glyphs {
        let yoff = g.box.width > 0 ? base - Int(g.box.maxY) : 0
        out += "char id=\(g.code) x=\(g.atlasX) y=\(g.atlasY) width=\(Int(g.box.width)) height=\(Int(g.box.height)) xoffset=\(Int(g.box.minX)) yoffset=\(yoff) xadvance=\(g.advance) page=0 chnl=15\n"
    }
    try! out.write(to: outDir.appendingPathComponent("\(spec.id).fnt"), atomically: true, encoding: .utf8)
    print("\(outDir.lastPathComponent == "fonts" ? outDir.deletingLastPathComponent().lastPathComponent : "?")/\(spec.id): \(Int(px)) px, line \(lineHeight), atlas \(atlasW)x\(atlasH)")
}

for target in targets {
    let dir = repo.appendingPathComponent(target.dir)
    for spec in specs(capBoost: target.capBoost) {
        build(spec: spec, diameter: target.diameter, outDir: dir)
    }
}
