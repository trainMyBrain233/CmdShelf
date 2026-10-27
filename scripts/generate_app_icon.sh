#!/usr/bin/env bash
set -euo pipefail

# Generate a single-layer macOS rounded-rect app icon (no inner card/background).
# Usage:
#   scripts/generate_app_icon.sh /path/to/source.png [scale] [radius]
# Example:
#   scripts/generate_app_icon.sh /Users/xingkong/Desktop/Gemini_Generated_Image_kpwus1kpwus1kpwu.png 1.0 210

SRC_IMAGE="${1:-}"
SCALE="${2:-1.0}"
RADIUS="${3:-210}"

if [[ -z "$SRC_IMAGE" ]]; then
  echo "Usage: $0 /path/to/source.png [scale] [radius]"
  exit 1
fi

if [[ ! -f "$SRC_IMAGE" ]]; then
  echo "Source image not found: $SRC_IMAGE"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_BASE="$ROOT_DIR/Sources/CmdShelf/Resources/AppIcon-1024.png"
ICONSET_DIR="$ROOT_DIR/Sources/CmdShelf/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$ICONSET_DIR"
mkdir -p /tmp/clang-module-cache
export CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache

SWIFT_SCRIPT="/tmp/cmdshelf_generate_icon.swift"
cat > "$SWIFT_SCRIPT" <<'SWIFT'
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
if args.count < 5 {
    fputs("missing args\n", stderr)
    exit(1)
}

let srcPath = args[1]
let outPath = args[2]
let scale = CGFloat(Double(args[3]) ?? 1.0)
let radius = CGFloat(Double(args[4]) ?? 210)

func savePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "icon", code: 2)
    }
}

guard let source = NSImage(contentsOfFile: srcPath),
      let tiff = source.tiffRepresentation,
      let srcRep = NSBitmapImageRep(data: tiff),
      let srcCG = srcRep.cgImage else {
    fputs("failed to load source image\n", stderr)
    exit(1)
}

let size: CGFloat = 1024
let clampedScale = max(0.5, min(1.0, scale))
let contentSize = size * clampedScale
let contentRect = CGRect(
    x: (size - contentSize) / 2,
    y: (size - contentSize) / 2,
    width: contentSize,
    height: contentSize
)

let outRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
outRep.size = NSSize(width: size, height: size)

guard let nsCtx = NSGraphicsContext(bitmapImageRep: outRep) else {
    fputs("failed to create graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let clipPath = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
clipPath.addClip()

let srcW = CGFloat(srcCG.width)
let srcH = CGFloat(srcCG.height)
let fillScale = max(contentRect.width / srcW, contentRect.height / srcH)
let drawW = srcW * fillScale
let drawH = srcH * fillScale
let drawRect = CGRect(
    x: contentRect.midX - drawW / 2,
    y: contentRect.midY - drawH / 2,
    width: drawW,
    height: drawH
)

nsCtx.cgContext.interpolationQuality = .high
nsCtx.cgContext.draw(srcCG, in: drawRect)

NSGraphicsContext.restoreGraphicsState()

// subtle edge stroke so icon boundary is clean on light/dark backgrounds
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
let strokePath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: radius - 1.5, yRadius: radius - 1.5)
NSColor.white.withAlphaComponent(0.10).setStroke()
strokePath.lineWidth = 3
strokePath.stroke()
NSGraphicsContext.restoreGraphicsState()

guard let outCG = outRep.cgImage else {
    fputs("failed to render output image\n", stderr)
    exit(1)
}

try savePNG(outCG, to: URL(fileURLWithPath: outPath))
print("generated: \(outPath) scale=\(clampedScale) radius=\(radius)")
SWIFT

swift "$SWIFT_SCRIPT" "$SRC_IMAGE" "$OUT_BASE" "$SCALE" "$RADIUS"

sips -z 16 16 "$OUT_BASE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$OUT_BASE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$OUT_BASE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$OUT_BASE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$OUT_BASE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$OUT_BASE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$OUT_BASE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$OUT_BASE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$OUT_BASE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$OUT_BASE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

echo "updated icon set in: $ICONSET_DIR"
