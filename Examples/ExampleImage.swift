//
//  ExampleImage.swift
//  SwiftCube
//
//  Created by Ronan Furuta on 10/8/24.
//

import CoreImage
import Foundation
import SwiftCube
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct SwiftUIView: View {
    @State var resultImage: UIImage? = nil
    @State var startImage: UIImage? = nil
    @State var error: String = ""
    var body: some View {
        VStack {
            if let startImage {
                Image(uiImage: startImage)
                    .resizable().aspectRatio(contentMode: .fit)
            }
            if let resultImage {
                Image(uiImage: resultImage)
                    .resizable().aspectRatio(contentMode: .fit)
            } else {
                Text("No image yet")
            }
            Text(error)
        }.onAppear {
            do {
                try self.proccess()
            } catch {
                print(error)
            }
        }
    }

    func proccess() throws {
        let url = Bundle.main.url(forResource: "SampleImage", withExtension: "jpeg")!
        let lutURL = Bundle.main.url(forResource: "SampleLUT", withExtension: "cube")!

        startImage = UIImage(contentsOfFile: url.path())
        let lutData = try Data(contentsOf: lutURL)
        let lut = try SC3DLut(rawData: lutData)
        print(lut.debugDescription)
        let filter = try lut.ciFilter()
        filter.setValue(CIImage(image: startImage!), forKey: kCIInputImageKey)

        guard let result = filter.outputImage else {
            error = "no result image"
            return
        }
        let context = CIContext(options: nil)
        if let cgimg = context.createCGImage(result, from: result.extent) {
            let processedImage = UIImage(cgImage: cgimg)
            // do something interesting with the processed image
            resultImage = processedImage
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    SwiftUIView()
}
