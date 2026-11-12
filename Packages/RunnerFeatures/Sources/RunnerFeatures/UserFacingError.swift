import Foundation
import RunnerCore
import RunnerPersistence

enum UserFacingError {
    static func message(for error: Error) -> String {
        if let parseError = error as? CollectionParseError {
            switch parseError {
            case .unsupportedSchema: return "Only Postman Collection v2.x files are supported."
            case .invalidJSON: return "The file is not a valid Postman collection."
            }
        }
        if let storeError = error as? StoreError, storeError == .notFound {
            return "Item not found."
        }
        return error.localizedDescription
    }
}
