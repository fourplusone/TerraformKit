//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 07.06.20.
//

import Foundation

extension Encodable {
    fileprivate func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
    
    public func asAnyEncodable() -> AnyEncodable {
        return AnyEncodable(self)
    }
}

public struct AnyEncodable : Encodable {
    var value: Encodable
    
    init(_ value: Encodable) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.encode(to: &container)
    }
}

