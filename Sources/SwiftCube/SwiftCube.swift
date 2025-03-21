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

func parseNumber(_ value: Substring) throws -> Float {
    guard let number = Float(value) else {
        throw SwiftCubeError.invalidSyntax(String(value.prefix(50)))
    }
    return number
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
        guard let stringData = String(bytes: fileData, encoding: .utf8) else {
            throw SwiftCubeError.couldNotDecodeData
        }
        for line in stringData.split(separator: /(\r|\n|\r\n)+/) {
            guard !line.isEmpty, line.first != "#" else {
                continue
            }
            let parts = line.split(separator: " ")
            switch parts.first {
            case "TITLE":
                title = String(String(parts.dropFirst().joined(separator: " ")).dropFirst().dropLast())
            case "LUT_1D_SIZE":
                throw SwiftCubeError.oneDimensionalLutNotSupported
            case "LUT_3D_SIZE":
                type = .threeDimensional
                guard parts.count == 2, let size = Int(parts[1]) else {
                    throw SwiftCubeError.invalidSyntax(String(line.prefix(50)))
                }
                self.size = size
                guard size < 100 else {
                    throw SwiftCubeError.sizeTooBig(size)
                }
            case "DOMAIN_MIN":
                throw SwiftCubeError.unsupportedKey("DOMAIN_MIN")
            case "DOMAIN_MAX":
                throw SwiftCubeError.unsupportedKey("DOMAIN_MAX")
            default:
                guard parts.count == 3 else {
                    throw SwiftCubeError.invalidSyntax(String(line.prefix(50)))
                }
                try entries.append(LutEntry(red: parseNumber(parts[0]),
                                            green: parseNumber(parts[1]),
                                            blue: parseNumber(parts[2])))
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

    /// Generate a CIFilter in the current device colorspace
    public func ciFilter() throws -> CIFilter & CIColorCubeWithColorSpace {
        var data: [Float] = []
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
