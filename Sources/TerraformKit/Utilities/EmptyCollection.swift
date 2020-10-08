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
    
    func decode(_ type: [Plan.Configuration.ResourceConfiguration].Type,
                forKey key: Key) throws -> [Plan.Configuration.ResourceConfiguration] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    
    func decode(_ type: [String: Plan.Configuration.ProviderConfig].Type,
                forKey key: Key) throws -> [String: Plan.Configuration.ProviderConfig] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Plan.Configuration.ModuleConfiguration.Property].Type,
                forKey key: Key) throws -> [String: Plan.Configuration.ModuleConfiguration.Property] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Plan.Configuration.ModuleCall].Type,
                forKey key: Key) throws -> [String: Plan.Configuration.ModuleCall] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Plan.Variable].Type,
                forKey key: Key) throws -> [String: Plan.Variable] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [Plan.ResourceChange].Type,
                forKey key: Key) throws -> [Plan.ResourceChange] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    
    func decode(_ type: [String: Plan.Change].Type,
                forKey key: Key) throws -> [String: Plan.Change] {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}
