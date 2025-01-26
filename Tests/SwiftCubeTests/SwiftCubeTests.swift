import CoreImage
import Foundation
@testable import SwiftCube
import Testing
import UIKit

@available(iOS 16.0, *)
@Test func importAndCreateLUT() async throws {
    let lutURL = Bundle.module.url(forResource: "SampleLUT", withExtension: "cube")!
    let lutData = try Data(contentsOf: lutURL)
    let lut = try SC3DLut(fileData: lutData)
    print(lut.debugDescription)
    let filter = try lut.ciFilter()

    let inputImageURL = Bundle.module.url(forResource: "SampleImage", withExtension: "jpg")!
    let startImage = UIImage(contentsOfFile: inputImageURL.path())
    filter.setValue(CIImage(image: startImage!), forKey: kCIInputImageKey)
    let result = filter.outputImage
    #expect(result != nil)
}

@available(iOS 16.0, *)
@Test func importAndCreateLUTFromURL() async throws {
    let lutURL = Bundle.module.url(forResource: "SampleLUT", withExtension: "cube")!

    let lut = try SC3DLut(contentsOf: lutURL)
    print(lut.debugDescription)
    let filter = try lut.ciFilter()

    let inputImageURL = Bundle.module.url(forResource: "SampleImage", withExtension: "jpg")!
    let startImage = UIImage(contentsOfFile: inputImageURL.path())
    filter.setValue(CIImage(image: startImage!), forKey: kCIInputImageKey)
    let result = filter.outputImage
    #expect(result != nil)
}

@Test func dataInOut() async throws {
    let lutURL = Bundle.module.url(forResource: "SampleLUT", withExtension: "cube")!
    let lutData = try Data(contentsOf: lutURL)
    let lut = try SC3DLut(fileData: lutData)
    print(lut.debugDescription)
    let filter = try lut.ciFilter()

    let data = try lut.rawDataRepresentation()

    let lut2 = try SC3DLut(dataRepresentation: data)

    #expect(lut.title == lut2.title)
    #expect(lut.data == lut2.data)
    #expect(lut.size == lut2.size)
    #expect(lut.type == lut2.type)
}
