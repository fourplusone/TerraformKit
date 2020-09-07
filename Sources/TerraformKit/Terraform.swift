import Foundation
import Dispatch

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Description of a Terraform version including all configured providers
public struct VersionDescription {
    let version: String
    let providers: [String: ProviderVersionDescription]
}

public struct ProviderVersionDescription {
    let version: String
}

@_implementationOnly import ZIPFoundation


public class Terraform {
    
    public static let defaultTerraformVersion = "0.13.2"
    let workingDirectoryURL : URL
    let usingWorkingDirectory: Bool
    let terraformExecutable: URL
    
    public enum TerraformError : Error {
        case unexpectedOutput
    }
    
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
        
    
    /// Configure a new Terraform environment. Terraform will be downloaded if necessary.
    /// - Parameters:
    ///   - configuration: An Encodable to be used as Terraform configuration. This object will be
    ///   encoded using the JSON decoder and saved to a file called main.tf.json
    ///   - workingDirectoryURL: URL of Terraforms working directory. If left empty, a temporary
    ///   directory will be created
    ///   - version: The version of Terraform to be used
    public init?(
        configuration: AnyEncodable? = nil,
        workingDirectoryURL : URL? = nil,
        version : String = Terraform.defaultTerraformVersion,
        terraformExecutable: URL? = nil
    ) {
        
        if let tfExecutable = terraformExecutable {
            self.terraformExecutable = tfExecutable
        } else {
            guard let tfExecutable = Terraform.downloadIfNeeded(version: version) else { return nil }
            self.terraformExecutable = tfExecutable
        }
        
        
        switch workingDirectoryURL {
        case .some(let url ):
            usingWorkingDirectory = false
            self.workingDirectoryURL = url
        case .none:
            let temporaryDir = URL(fileURLWithPath: NSTemporaryDirectory())
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
    
    /// Remove the temporary working directory of terraform. Calling this function is not allowed, if a
    /// working directory was specified in the initializer
    public func cleanup() {
        precondition(usingWorkingDirectory, "Only a temporary working directory can be cleaned up automatically")
        try! FileManager.default.removeItem(at: workingDirectoryURL)
    }
    
    /// Run `terraform init`
    public func initialize() throws {
        try invoke(arguments: ["init", workingDirectoryURL.path])
    }
    
    /// Run `terraform plan`
    public func plan() throws {
        try invoke(arguments: ["plan", workingDirectoryURL.path])
    }
    
    /// Run `terraform apply`
    public func apply() throws {
        try invoke(arguments: ["apply", workingDirectoryURL.path])
    }
    
    /// Run `terraform destroy`
    public func destroy() throws {
        try invoke(arguments: ["destroy", workingDirectoryURL.path])
    }
    
    /// Fetch the current provider schema
    /// - Returns: The schema description
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
    
    
    /// Determine the currenly used version of terraform and the versions of all installed providers
    /// - Returns: The current version of terraform and all configured providers
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
        
        var terraformVersion : String?
        var providerDescriptions : [String : ProviderVersionDescription] = [:]
        
        for line in lines {
            if line.starts(with: "Terraform") {
                terraformVersion = String(line.split(separator: " ")[1].dropFirst())
            }
            if line.starts(with: "+") {
                let components = line.split(separator: " ")
                providerDescriptions[String(components[1])] = ProviderVersionDescription(version: String(components[2].dropFirst()))
            }
        }
        
        guard terraformVersion != nil else { throw TerraformError.unexpectedOutput }
        
        return VersionDescription(version: terraformVersion!, providers: providerDescriptions)
    }
}
