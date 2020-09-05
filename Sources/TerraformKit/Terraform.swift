import Foundation
import Dispatch

public struct VersionDescription {
    var name: String
    var version: String
    
    var submodules: [VersionDescription] = []
}

@_implementationOnly import ZIPFoundation


public class Terraform {
    
    public static let defaultTerraformVersion = "0.13.2"
    let workingDirectoryURL : URL
    let usingWorkingDirectory: Bool
    let terraformExecutable: URL
    
    
    
    private static func download(version: String, arch: String) throws {
        let fm = FileManager.default
        
        let binaryURL = terraformBinaryURL(version: version, arch: arch)
        let downloadURL = URL(string: "https://releases.hashicorp.com/terraform/\(version)/terraform_\(version)_\(arch).zip")!
        let destinationDir = binaryURL.deletingLastPathComponent()
        
        var downloadedURL: URL?
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.downloadTask(with: downloadURL) { (url, response, error) in
            downloadedURL = url
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        
        if (downloadedURL == nil) { return }
        
        do {
            try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        } catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain, error.code == CocoaError.fileWriteFileExists.rawValue {
                // Do nothing
            } else {
                throw error
            }
        }
        
        let temporaryURL = try fm.url(for: .itemReplacementDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: destinationDir,
                                      create: false)
        
        try fm.unzipItem(at:downloadedURL!, to:temporaryURL, skipCRC32: true)
        
        #if os(Windows)
        try fm.moveItem(at: temporaryURL.appendingPathComponent("terraform.exe"),
                        to: binaryURL)
        #else
        try fm.moveItem(at: temporaryURL.appendingPathComponent("terraform"),
                        to: binaryURL)
        #endif
        
        
    }
    
    static private func terraformBinaryName(version: String, arch: String) -> String {
        #if os(Windows)
        return "terraform_\(version)_\(arch).exe"
        #else
        return "terraform_\(version)_\(arch)"
        #endif
    }
    
    static private func terraformBinaryURL(version: String, arch: String) -> URL {
        let fm = FileManager.default
        return try! fm.url(for: .cachesDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: nil,
                                 create:false)
            .appendingPathComponent("TerraformKit")
            .appendingPathComponent(terraformBinaryName(version: version, arch: arch))
        
    }
    
    static func downloadIfNeeded(version: String) -> URL? {
        
        #if arch(x86_64)
            #if os(Linux)
            let arch = "linux_amd64"
            #elseif os(macOS)
            let arch = "darwin_amd64"
            #elseif os(Windows)
            let arch = "windows_amd64"
            #endif
        #else
            #error("Architecture / OS is not supported")
        #endif
        
        
        
        let terraformBinary = terraformBinaryURL(version: defaultTerraformVersion, arch: arch)
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: terraformBinary.path) {
            do {
                try download(version: version, arch: arch)
            } catch _ {
                return nil
            }
        }
        
        return terraformBinary
    }
        
    public init?(configuration: AnyEncodable? = nil, workingDirectoryURL : URL? = nil, version : String = Terraform.defaultTerraformVersion) {
        guard let tfExecutable = Terraform.downloadIfNeeded(version: version) else { return nil }
        terraformExecutable = tfExecutable
        
        let temporaryDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        switch workingDirectoryURL {
        case .some(let url ):
            usingWorkingDirectory = false
            self.workingDirectoryURL = url
        case .none:
            usingWorkingDirectory = true
            self.workingDirectoryURL = temporaryDir.appendingPathComponent(UUID.init().uuidString)
        }
        
        do {
            try FileManager.default.createDirectory(at:self.workingDirectoryURL, withIntermediateDirectories:false)
            
            if let configuration = configuration {
                let encoder = JSONEncoder()
                let encoded = try encoder.encode(configuration)
                try encoded.write(to: self.workingDirectoryURL.appendingPathComponent("main.tf.json"))
            }
            
            
        } catch _ {
            return nil
        }
    }
    
    public func cleanup() {
        precondition(usingWorkingDirectory, "Only a temporary working directory can be cleaned up automatically")
        try! FileManager.default.removeItem(at: workingDirectoryURL)
    }
    
    public func initialize() throws {
        try invoke(arguments: ["init", workingDirectoryURL.path])
    }
    
    public func plan() throws {
        try invoke(arguments: ["plan", workingDirectoryURL.path])
    }
    
    public func apply() throws {
        try invoke(arguments: ["apply", workingDirectoryURL.path])
    }
    
    public func destroy() throws {
        try invoke(arguments: ["destroy", workingDirectoryURL.path])
    }
    
    public func schema() throws -> SchemaDescription {
        let outPipe = Pipe()
        var buffer = Data()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            buffer.append(handle.availableData)
        }
        
        try invoke(arguments: ["providers", "schema", "-json"], stdout:outPipe)
        outPipe.fileHandleForReading.closeFile()
        
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try! jsonDecoder.decode(SchemaDescription.self, from:buffer)
    }
    
    public func version() throws -> VersionDescription {
        let outPipe = Pipe()
        var buffer = Data()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            buffer.append(handle.availableData)
        }
        
        try invoke(arguments: ["version"], stdout:outPipe)
        outPipe.fileHandleForReading.closeFile()
        
        let output = String(data: buffer, encoding: .utf8)!
        
        let lines = output.split(separator: "\n")
        
        var versionDescription = VersionDescription(name: "Terraform", version: "")
        
        for line in lines {
            if line.starts(with: "Terraform") {
                versionDescription.version = String(line.split(separator: " ")[1].dropFirst())
            }
            if line.starts(with: "+") {
                let components = line.split(separator: " ")
                
                versionDescription.submodules.append(
                    VersionDescription(name: String(components[1]),
                                       version: String(components[2].dropFirst()))
                )
            }
        }
        
        return versionDescription
    }
}
