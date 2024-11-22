import Foundation

enum FileManagerError: Error {
    case failedToCreateDirectory
    case failedToDeleteDirectory
}

class FileManagerHelper {
    static let shared = FileManagerHelper()
    private let fileManager = FileManager.default
    
    func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func createBookDirectory(title: String) throws -> URL {
        let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
        let bookDirectory = getDocumentsDirectory().appendingPathComponent(sanitizedTitle)
        
        if !fileManager.fileExists(atPath: bookDirectory.path) {
            do {
                try fileManager.createDirectory(at: bookDirectory, withIntermediateDirectories: true)
            } catch {
                throw FileManagerError.failedToCreateDirectory
            }
        }
        
        return bookDirectory
    }
    
    func deleteBookDirectory(title: String) throws {
        let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
        let bookDirectory = getDocumentsDirectory().appendingPathComponent(sanitizedTitle)
        
        if fileManager.fileExists(atPath: bookDirectory.path) {
            do {
                try fileManager.removeItem(at: bookDirectory)
            } catch {
                throw FileManagerError.failedToDeleteDirectory
            }
        }
    }
}
