//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 13.09.20.
//

import Foundation

public enum Mode : String, Decodable {
    /// The  resource is managed by terraform
    case managed
    
    /// The resource is a data source
    case data
}

public struct Module : Decodable {
    public var resources : [Resource]
    
    public var childModules: [ChildModule]
    
    
    
    public struct ChildModule : Decodable {
        /// "address" is the absolute module address, which callers must treat as
        /// opaque but may do full string comparisons with other module address
        /// strings and may pass verbatim to other Terraform commands that are
        /// documented as accepting absolute module addresses.
        public let address : String
        
        public var resources : [Resource]
        
        public var childModules: [ChildModule]
    }
    
    public struct Resource : Decodable {
        /// `address` is the absolute resource address, which callers must consider
        /// opaque but may do full string comparisons with other address strings or
        /// pass this verbatim to other Terraform commands that are documented to
        /// accept absolute resource addresses. The module-local portions of this
        /// address are extracted in other properties below.
        public let address : String
        
        
        public let mode : Mode
        public let type : String
        public let name : String
        
        /// If the count or for_each meta-arguments are set for this resource, the
        /// additional key "index" is present to give the instance index key. This
        /// is omitted for the single instance of a resource that isn't using count
        /// or for_each.
        public let index: Int64?
        
        public let providerName : String
        
        public let schemaVersion : Int64
        
        public let values : [String: AnyDecodable]?
    }

}

/// A values representation is used in both state and plan output to describe current state (which is always
/// complete) and planned state (which omits values not known until apply).
public struct Values : Decodable {
    
    /// `outputs` describes the outputs from the root module. Outputs from
    /// descendent modules are not available because they are not retained in all
    /// of the underlying structures we will build this values representation from.
    public let outputs : Dictionary<String, AnyDecodable>
    
    /// `rootModule` describes the resources and child modules in the root module.
    public let rootModule: Module?
    
    
    public init(from decoder:Decoder) throws{
        enum CodingKeys : String, CodingKey {
            case outputs
            case rootModule
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rootModule = try container.decodeIfPresent(Module.self, forKey: .rootModule)
        outputs = try container.decodeIfPresent(Dictionary<String, AnyDecodable>.self,
                                                forKey: .outputs) ?? [:]
        
    }
}
