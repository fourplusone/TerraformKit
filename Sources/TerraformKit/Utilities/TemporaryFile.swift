import Foundation

struct TemporaryFile {
    
    let url: URL
    
    var path : String { get { url.path }}
    
    init(create: Bool = false) {
        let temporaryFileName = UUID.init().uuidString
        self.url = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryFileName)
    }
}

func withTemporaryFile<Result> (closure: (_ file: TemporaryFile) throws -> Result ) throws -> Result {
    let file = TemporaryFile()
    defer { try? FileManager.default.removeItem(at: file.url) }
    
    return try closure(file)
}
