import Foundation
import Dispatch

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Description of a Terraform version including all configured providers
public struct VersionDescription {
    /// Terraform Version
    public let version: String
    
    /// Dictionary containing all provider versions. The key refers to the provider name
    public let providers: [String: ProviderVersionDescription]
    
    /// Description of a provider version
    public struct ProviderVersionDescription {
        /// Provider version
        public let version: String
    }
}



@_implementationOnly import ZIPFoundation

public enum ColorMode {
    case none
    case colored
}


/// Control how the stdout/stderr output of terraform is handled
public enum Output {
    /// Discard the output
    case discard
    
    /// Forward the output to stdout/stderr
    case passthrough
    
    /// Forward the output to stdout/stderr, if the exit code is non-zero
    case passthroughOnFailure
    
    /// Collect the output and invoke the closure once the process has ended.
    case collect( (Data) -> Void )
}

/// A `Terraform` object is a wrapper around the terraform executable. It can be used to perform common
/// operations like planning and applying changes, retrieving provider schemas and retrieving versions
///
/// This class is the only object to be instanciated directly by the user.
public class Terraform {
    
    public static let defaultTerraformVersion = "0.13.2"
    let workingDirectoryURL : URL
    let usingTemporaryWorkingDirectory: Bool
    let terraformExecutable: URL
    
    public struct InvocationSettings {
        let stderr: Output
        let stdout: Output
        let colorMode: ColorMode
    }
    
    static let defaultInvocationSettings = InvocationSettings(
        stderr: .passthroughOnFailure,
        stdout: .passthroughOnFailure,
        colorMode: .none)
    
    static let internalInvocationSettings = InvocationSettings(
        stderr: .discard,
        stdout: .discard,
        colorMode: .none)
    
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
        terraformExecutable: URL? = nil,
        colorMode : ColorMode = .none
    ) {
        
        
        if let tfExecutable = terraformExecutable {
            self.terraformExecutable = tfExecutable
        } else {
            guard let tfExecutable = Terraform.downloadIfNeeded(version: version) else { return nil }
            self.terraformExecutable = tfExecutable
        }
        
        
        switch workingDirectoryURL {
        case .some(let url):
            usingTemporaryWorkingDirectory = false
            self.workingDirectoryURL = url
        case .none:
            let temporaryDir = URL(fileURLWithPath: NSTemporaryDirectory())
            usingTemporaryWorkingDirectory = true
            self.workingDirectoryURL = temporaryDir.appendingPathComponent(UUID.init().uuidString)
        }
        
        do {
            if usingTemporaryWorkingDirectory {
                try FileManager.default.createDirectory(at:self.workingDirectoryURL,
                                                        withIntermediateDirectories:false)
            }
            
            if let configuration = configuration {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
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
        precondition(usingTemporaryWorkingDirectory, "Only a temporary working directory can be cleaned up automatically")
        try! FileManager.default.removeItem(at: workingDirectoryURL)
    }
    
    /// Run `terraform init`
    public func initialize(invocationSettings: InvocationSettings? = nil) throws {
        try invoke("init", arguments: [workingDirectoryURL.path],
                   invocationSettings: invocationSettings ?? Self.defaultInvocationSettings)
    }
    
    /// Run `terraform plan`
    public func plan(invocationSettings: InvocationSettings? = nil) throws -> Plan {
        try withTemporaryFile { (planFile) -> Plan in
            try invoke("plan", arguments: ["-out", planFile.path],
            invocationSettings: invocationSettings ?? Self.defaultInvocationSettings)
            
            var buffer = Data()
            
            try invoke("show", arguments: ["-json", planFile.path], invocationSettings:
                InvocationSettings(
                stderr: .passthrough,
                stdout: .collect { (data) in
                    buffer = data
                },
                colorMode:.none)
            )
            
            let decoder = TerraformDecoder()
            
            var plan = try decoder.decode(Plan.self, from: buffer)
            plan.source = try Data(contentsOf: planFile.url)
            
            return plan
        }
    }
    
    /// Retrieve the current state
    /// - Throws:
    /// - Returns: A  `State` Object
    public func state() throws -> State {
        var buffer = Data()
        try invoke("show", arguments: ["-json"],
                   invocationSettings: InvocationSettings(
                    stderr: .passthrough,
                    stdout: .collect { (data) in
                        buffer = data
                    },
                    colorMode:.none))
        
        let decoder = TerraformDecoder()
        return try decoder.decode(State.self, from: buffer)
    }
    
    /// Run `terraform apply`
    /// - Parameter plan: The plan to execute
    public func apply(plan: Plan, invocationSettings: InvocationSettings? = nil) throws {
        try withTemporaryFile { (planFile) -> () in
            try plan.source.write(to: planFile.url)
            try invoke("apply", arguments: ["-auto-approve", "-input=false" , planFile.path],
            invocationSettings: invocationSettings ?? Self.defaultInvocationSettings)
        }
    }
    
    /// Run `terraform destroy`
    public func destroy(invocationSettings: InvocationSettings? = nil) throws {
        try invoke("destroy", arguments: ["-auto-approve", workingDirectoryURL.path],
                   invocationSettings: invocationSettings ?? Self.defaultInvocationSettings)
    }
    
    /// Fetch the current provider schema
    /// - Returns: The schema description
    public func schema() throws -> SchemaDescription {
        var buffer = Data()
        try invoke(command:["providers", "schema"], arguments: ["-json"], invocationSettings: InvocationSettings(
            stderr: .passthrough,
            stdout: .collect { (data) in
                buffer = data
            },
            colorMode:.none)
        )

        let decoder = TerraformDecoder()
        
        return try! decoder.decode(SchemaDescription.self, from:buffer)
    }
    
    /// Determine the currenly used version of terraform and the versions of all installed providers
    /// - Returns: The current version of terraform and all configured providers
    public func version() throws -> VersionDescription {
        var buffer = Data()
        
        try invoke("version", arguments: [], invocationSettings: InvocationSettings(
            stderr: .passthrough,
            stdout: .collect { (data) in
                buffer = data
            },
        colorMode:.none))
        
        let output = String(data: buffer, encoding: .utf8)!
        
        let lines = output.split(separator: "\n")
        
        var terraformVersion : String?
        var providerDescriptions : [String : VersionDescription.ProviderVersionDescription] = [:]
        
        for line in lines {
            if line.starts(with: "Terraform") {
                terraformVersion = String(line.split(separator: " ")[1].dropFirst())
            }
            if line.starts(with: "+") {
                let components = line.split(separator: " ")
                providerDescriptions[String(components[1])] = VersionDescription.ProviderVersionDescription(version: String(components[2].dropFirst()))
            }
        }
        
        guard terraformVersion != nil else { throw TerraformError.unexpectedOutput }
        
        return VersionDescription(version: terraformVersion!, providers: providerDescriptions)
    }
}
