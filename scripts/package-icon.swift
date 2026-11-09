import AppKit
let source = NSImage(contentsOfFile: CommandLine.arguments[1])!
let out = CommandLine.arguments[2]
try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
 for scale in [1,2] {
  let pixels = size * scale
  let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
  NSGraphicsContext.current!.imageInterpolation = .high
  source.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels),from:.zero,operation:.copy,fraction:1)
  NSGraphicsContext.restoreGraphicsState()
  let suffix = scale == 2 ? "@2x" : ""
  try rep.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath:"\(out)/icon_\(size)x\(size)\(suffix).png"))
 }
}
