import UIKit
import UniformTypeIdentifiers

func encodeImageToBase64(_ img: UIImage,
                         mime: String = "image/png") -> String {
    let data = mime.contains("png") ? img.pngData()! : img.jpegData(compressionQuality: 0.9)!
    return data.base64EncodedString()
}

func encodeFileToBase64(_ url: URL) -> (b64: String, mime: String, name: String) {
    let data = try! Data(contentsOf: url)
    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    return (data.base64EncodedString(), mime, url.lastPathComponent)
}
