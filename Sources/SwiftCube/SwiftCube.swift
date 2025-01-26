import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public struct LutEntry {
    let red: Float
    let green: Float
    let blue: Float
}

func parseNumber(_ value: Substring) throws -> Float {
    guard let number = Float(value) else {
        throw SwiftCubeError.invalidDataPoint
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
        let stringData = String(decoding: fileData, as: UTF8.self)
        guard !stringData.isEmpty else {
            throw SwiftCubeError.couldNotDecodeData
        }
        for line in stringData.components(separatedBy: "\n") {
            guard !line.isEmpty, line.first != "#" else {
                continue
            }
            let parts = line.split(separator: " ")
            switch parts.first {
            case "TITLE":
                title = String(String(parts.dropFirst().joined(separator: " ")).dropFirst().dropLast())
            case "LUT_3D_SIZE":
                type = .threeDimensional
                guard parts.count == 2, let size = Int(parts[1]) else {
                    throw SwiftCubeError.invalidSize
                }
                self.size = size
            case "LUT_1D_SIZE":
                throw SwiftCubeError.oneDimensionalLutNotSupported
            case "DOMAIN_MIN":
                throw SwiftCubeError.unsupportedKey
            case "DOMAIN_MAX":
                throw SwiftCubeError.unsupportedKey
            default:
                guard parts.count == 3 else {
                    throw SwiftCubeError.invalidDataPoint
                }
                try entries.append(LutEntry(red: parseNumber(parts[0]),
                                            green: parseNumber(parts[1]),
                                            blue: parseNumber(parts[2])))
            }
        }
        guard size != nil else {
            throw SwiftCubeError.invalidSize
        }
        guard type != nil else {
            throw SwiftCubeError.invalidType
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
    case invalidSize
    case oneDimensionalLutNotSupported
    case unsupportedKey
    case invalidType
    case invalidDataPoint
}
