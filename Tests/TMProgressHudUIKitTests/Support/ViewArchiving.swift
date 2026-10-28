import Foundation
import UIKit
import Testing

@MainActor
func archiveRoundTrip<View: UIView>(_ view: View) throws -> View {
    let data = try NSKeyedArchiver.archivedData(withRootObject: view, requiringSecureCoding: false)
    let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
    decoder.requiresSecureCoding = false
    defer { decoder.finishDecoding() }
    return try #require(decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? View)
}
