import AppKit
import Foundation

@main enum KageIconBuilder {
    static func main() throws {
        let output=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let iconset=output.appendingPathComponent("KageIcon.iconset",isDirectory:true)
        try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
        func bitmap(_ pixels:Int)->NSBitmapImageRep {
            let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
            let size=CGFloat(pixels),bounds=NSRect(x:0,y:0,width:size,height:size)
            NSColor.clear.setFill();bounds.fill()
            let tile=NSBezierPath(roundedRect:bounds.insetBy(dx:size*0.04,dy:size*0.04),xRadius:size*0.22,yRadius:size*0.22)
            NSGradient(starting:NSColor(srgbRed:0.13,green:0.07,blue:0.085,alpha:1),ending:NSColor(srgbRed:0.035,green:0.038,blue:0.05,alpha:1))!.draw(in:tile,angle:-90)
            NashiArtwork.gold.withAlphaComponent(0.30).setStroke();tile.lineWidth=max(1,size*0.004);tile.stroke()
            NashiArtwork.draw(in:bounds.insetBy(dx:size*0.20,dy:size*0.20))
            NSGraphicsContext.restoreGraphicsState();return rep
        }
        for size in [16,32,128,256,512] {for factor in [1,2] {
            let data=bitmap(size*factor).representation(using:.png,properties:[:])!
            try data.write(to:iconset.appendingPathComponent("icon_\(size)x\(size)\(factor==2 ? "@2x":"").png"))
        }}
        try bitmap(1024).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("KageIcon.png"))
    }
}
