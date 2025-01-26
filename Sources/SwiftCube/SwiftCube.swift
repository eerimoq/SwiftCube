import BinaryCodable
import CoreImage
import CoreImage.CIFilterBuiltins

// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

/// SwiftCube representation of a 3D LUT
public struct SC3DLut: CustomDebugStringConvertible, Codable {
    public var title: String? = nil
    public var type: LUTType! = nil
    public var size: Int! = nil
    public var data: [[Float]] = []

    /// Initialize a LUT from a URL
    public init(contentsOf url: URL) throws {
        try self.init(fileData: Data(contentsOf: url))
    }

    /// Initialize a LUT from a Data object generated from the .rawDataRepresentation() method
    public init(dataRepresentation: Data) throws {
        self = try BinaryDecoder().decode(SC3DLut.self, from: dataRepresentation)
    }

    /// Initialize a LUT from a .cube file's data
    public init(fileData: Data) throws {
        let stringData = String(decoding: fileData, as: UTF8.self)
        guard !stringData.isEmpty else {
            throw SwiftCubeError.couldNotDecodeData
        }
        for line in stringData.components(separatedBy: "\n") {
            guard !line.isEmpty && line.first != "#" else {
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
                try data.append(parts.map {
                    guard let double = Float($0) else {
                        throw SwiftCubeError.invalidDataPoint
                    }
                    return double
                })
            }
        }
        guard size != nil else {
            throw SwiftCubeError.invalidSize
        }
        guard type != nil else {
            throw SwiftCubeError.invalidType
        }
    }

    public var debugDescription: String {
        return "LUT \(title ?? "") \(type) \(size) \(data.count)"
    }

    /// Generate a CIFilter in the current device colorspace
    public func ciFilter() throws -> CIFilter & CIColorCubeWithColorSpace {
        var data: [Float] = []
        for line in self.data {
            guard line.count == 3 else {
                throw SwiftCubeError.invalidDataPoint
            }
            data += line
            data.append(1.0)
        }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = Float(size)
        filter.cubeData = Data(bytes: data, count: data.count * 4)
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        return filter
    }

    /// Generate a binary Data representation of the LUT for storage
    public func rawDataRepresentation() throws -> Data {
        let encoder = BinaryEncoder()
        let data = try encoder.encode(self)
        return data
    }
}

public enum LUTType: Codable {
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
