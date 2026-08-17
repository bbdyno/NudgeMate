#!/usr/bin/env swift

import AppKit
import Foundation

private struct ScreenshotSpec {
    let inputName: String
    let outputName: String
    let eyebrow: String
    let title: String
    let subtitle: String
}

private let canvasSize = NSSize(width: 1320, height: 2868)
private let deviceCrop = CGRect(x: 0, y: 128, width: 930, height: 1860)

private let specs = [
    ScreenshotSpec(
        inputName: "01_today_window.png",
        outputName: "01_today.png",
        eyebrow: "오늘",
        title: "오늘 챙길 일을\n한눈에",
        subtitle: "준비와 반복 일정을 한 화면에서 확인하세요"
    ),
    ScreenshotSpec(
        inputName: "02_rhythms_window.png",
        outputName: "02_rhythms.png",
        eyebrow: "리듬",
        title: "반복 일정의\n다음 시점을 미리",
        subtitle: "지난 일정의 리듬을 바탕으로 다음 때를 추천해요"
    ),
    ScreenshotSpec(
        inputName: "03_prep_window.png",
        outputName: "03_prep.png",
        eyebrow: "준비",
        title: "중요한 날까지\n차근차근 준비",
        subtitle: "해야 할 일과 준비 상태를 놓치지 않아요"
    ),
    ScreenshotSpec(
        inputName: "04_onboarding_window.png",
        outputName: "04_onboarding.png",
        eyebrow: "캘린더 발견",
        title: "내 캘린더에서\n리듬을 발견",
        subtitle: "분석은 기기 안에서, 저장은 내가 확인한 항목만"
    )
]

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

private func topRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasSize.height - y - height, width: width, height: height)
}

private func drawText(
    _ text: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    paragraph.alignment = .left
    (text as NSString).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

private func render(spec: ScreenshotSpec, inputDirectory: URL, outputDirectory: URL) throws {
    let inputURL = inputDirectory.appendingPathComponent(spec.inputName)
    guard
        let sourceImage = NSImage(contentsOf: inputURL),
        let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let croppedCGImage = sourceCGImage.cropping(to: deviceCrop)
    else {
        throw NSError(domain: "ScreenshotRenderer", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not load or crop \(inputURL.path)"
        ])
    }

    let deviceImage = NSImage(cgImage: croppedCGImage, size: deviceCrop.size)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let cgContext = CGContext(
        data: nil,
        width: Int(canvasSize.width),
        height: Int(canvasSize.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(canvasSize.width) * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw NSError(domain: "ScreenshotRenderer", code: 2)
    }

    let context = NSGraphicsContext(cgContext: cgContext, flipped: false)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let background = NSGradient(colors: [color(0x211936), color(0x0A0D16)])!
    background.draw(in: NSRect(origin: .zero, size: canvasSize), angle: -68)

    color(0xAA8BE8, alpha: 0.12).setFill()
    NSBezierPath(ovalIn: topRect(x: 905, y: 30, width: 520, height: 520)).fill()
    color(0xFF816F, alpha: 0.10).setFill()
    NSBezierPath(ovalIn: topRect(x: -170, y: 360, width: 480, height: 480)).fill()

    let eyebrowRect = topRect(x: 104, y: 92, width: 320, height: 54)
    let eyebrowPath = NSBezierPath(roundedRect: eyebrowRect, xRadius: 27, yRadius: 27)
    color(0xAA8BE8, alpha: 0.22).setFill()
    eyebrowPath.fill()
    drawText(
        "NUDGEMATE 1.1.0  ·  \(spec.eyebrow)",
        rect: topRect(x: 130, y: 105, width: 420, height: 32),
        font: .systemFont(ofSize: 24, weight: .semibold),
        color: color(0xC8B1FA)
    )

    drawText(
        spec.title,
        rect: topRect(x: 104, y: 172, width: 1110, height: 238),
        font: .systemFont(ofSize: 82, weight: .bold),
        color: color(0xF8F7FC),
        lineSpacing: -4
    )
    drawText(
        spec.subtitle,
        rect: topRect(x: 108, y: 430, width: 1110, height: 58),
        font: .systemFont(ofSize: 34, weight: .medium),
        color: color(0xB5B8C9)
    )

    let deviceHeight: CGFloat = 2285
    let deviceWidth = deviceHeight * deviceCrop.width / deviceCrop.height
    let deviceRect = topRect(
        x: (canvasSize.width - deviceWidth) / 2,
        y: 590,
        width: deviceWidth,
        height: deviceHeight
    )

    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.65)
    shadow.shadowBlurRadius = 46
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    deviceImage.draw(in: deviceRect, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()

    guard let outputCGImage = cgContext.makeImage() else {
        throw NSError(domain: "ScreenshotRenderer", code: 4)
    }
    let bitmap = NSBitmapImageRep(cgImage: outputCGImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ScreenshotRenderer", code: 5)
    }
    try pngData.write(to: outputDirectory.appendingPathComponent(spec.outputName), options: .atomic)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: render_app_store_screenshots.swift <framed-input-directory> <output-directory>\n", stderr)
    exit(64)
}

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    try render(spec: spec, inputDirectory: inputDirectory, outputDirectory: outputDirectory)
    print("Rendered \(spec.outputName)")
}
