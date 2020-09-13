//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 13.09.20.
//

import Foundation
typealias ChildModules = [Module.ChildModule]

extension KeyedDecodingContainer {
    func decode(_ type: [Module.Resource].Type,
                forKey key: Key) throws -> [Module.Resource] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [Module.ChildModule].Type,
                forKey key: Key) throws -> [Module.ChildModule] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [Configuration.ResourceConfiguration].Type,
                forKey key: Key) throws -> [Configuration.ResourceConfiguration] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    
    func decode(_ type: [String: Configuration.ProviderConfig].Type,
                forKey key: Key) throws -> [String: Configuration.ProviderConfig] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Configuration.ModuleConfiguration.Property].Type,
                forKey key: Key) throws -> [String: Configuration.ModuleConfiguration.Property] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Configuration.ModuleCall].Type,
                forKey key: Key) throws -> [String: Configuration.ModuleCall] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}
