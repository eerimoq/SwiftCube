import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public struct LutEntry {
    public let red: Float
    public let green: Float
    public let blue: Float
    
    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

private let space = UInt8(ascii: " ")
private let tab = UInt8(ascii: "\t")
private let newline = UInt8(ascii: "\n")
private let carriageReturn = UInt8(ascii: "\r")
private let hash = UInt8(ascii: "#")

private func isSpace(_ byte: UInt8) -> Bool {
    byte == space || byte == tab
}

private func skipSpaces(_ line: UnsafeBufferPointer<UInt8>, _ index: inout Int) {
    while index < line.count, isSpace(line[index]) {
        index += 1
    }
}

private func parseNumber(_ line: UnsafeBufferPointer<UInt8>, _ index: inout Int) -> Float? {
    var end = index
    while end < line.count, !isSpace(line[end]) {
        end += 1
    }
    guard end > index, let value = Float(String(decoding: line[index ..< end], as: UTF8.self)) else {
        return nil
    }
    index = end
    return value
}

private func parseEntry(_ line: UnsafeBufferPointer<UInt8>, _ index: inout Int) -> LutEntry? {
    guard let red = parseNumber(line, &index) else {
        return nil
    }
    skipSpaces(line, &index)
    guard let green = parseNumber(line, &index) else {
        return nil
    }
    skipSpaces(line, &index)
    guard let blue = parseNumber(line, &index) else {
        return nil
    }
    skipSpaces(line, &index)
    guard index == line.count else {
        return nil
    }
    return LutEntry(red: red, green: green, blue: blue)
}

private func makeInvalidSyntaxError(_ line: UnsafeBufferPointer<UInt8>) -> SwiftCubeError {
    .invalidSyntax(String(bytes: line.prefix(50), encoding: .utf8) ?? "")
}

/// SwiftCube representation of a 3D LUT
public struct SC3DLut {
    public var title: String?
    public var type: LutType!
    public var size: Int!
    public var entries: [LutEntry] = []

    /// Initialize a LUT from a URL
    public init(contentsOf url: URL) throws {
        try self.init(fileData: Data(contentsOf: url))
    }

    /// Initialize a LUT from a .cube file's data
    public init(fileData: Data) throws {
        try fileData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            let bytes = buffer.bindMemory(to: UInt8.self)
            var start = 0
            while start < bytes.count {
                var end = start
                while end < bytes.count, bytes[end] != newline, bytes[end] != carriageReturn {
                    end += 1
                }
                let line = UnsafeBufferPointer(rebasing: bytes[start ..< end])
                start = end + 1
                try parseLine(line)
            }
        }
        guard let size else {
            throw SwiftCubeError.sizeMissing
        }
        guard let type else {
            throw SwiftCubeError.typeMissing
        }
        switch type {
        case .oneDimensional:
            guard entries.count == size else {
                throw SwiftCubeError.wrongNumberOfDataPoints(entries.count)
            }
        case .threeDimensional:
            guard entries.count == size * size * size else {
                throw SwiftCubeError.wrongNumberOfDataPoints(entries.count)
            }
        }
    }

    private mutating func parseLine(_ line: UnsafeBufferPointer<UInt8>) throws {
        var index = 0
        skipSpaces(line, &index)
        guard index < line.count, line[index] != hash else {
            return
        }
        if type == .threeDimensional, let entry = parseEntry(line, &index) {
            entries.append(entry)
            return
        }
        guard let text = String(bytes: line, encoding: .utf8) else {
            throw SwiftCubeError.couldNotDecodeData
        }
        let parts = text.split(whereSeparator: { $0 == " " || $0 == "\t" })
        switch parts.first {
        case "TITLE":
            title = String(String(parts.dropFirst().joined(separator: " ")).dropFirst().dropLast())
        case "LUT_1D_SIZE":
            throw SwiftCubeError.oneDimensionalLutNotSupported
        case "LUT_3D_SIZE":
            type = .threeDimensional
            guard parts.count == 2, let size = Int(parts[1]) else {
                throw makeInvalidSyntaxError(line)
            }
            self.size = size
            guard size < 100 else {
                throw SwiftCubeError.sizeTooBig(size)
            }
            entries.reserveCapacity(size * size * size)
        case "DOMAIN_MIN":
            throw SwiftCubeError.unsupportedKey("DOMAIN_MIN")
        case "DOMAIN_MAX":
            throw SwiftCubeError.unsupportedKey("DOMAIN_MAX")
        default:
            throw makeInvalidSyntaxError(line)
        }
    }

    /// Generate a CIFilter in the current device colorspace
    public func ciFilter() throws -> CIFilter & CIColorCubeWithColorSpace {
        var data: [Float] = []
        data.reserveCapacity(entries.count * 4)
        for entry in entries {
            data.append(entry.red)
            data.append(entry.green)
            data.append(entry.blue)
            data.append(1.0)
        }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = Float(size)
        filter.cubeData = Data(bytes: data, count: data.count * 4)
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        return filter
    }
}

public enum LutType: Codable {
    case oneDimensional
    case threeDimensional
}

public enum SwiftCubeError: Error {
    case couldNotDecodeData
    case sizeMissing
    case sizeTooBig(Int)
    case oneDimensionalLutNotSupported
    case unsupportedKey(String)
    case invalidType
    case typeMissing
    case invalidDataPoint(String)
    case wrongNumberOfDataPoints(Int)
    case invalidSyntax(String)
}
