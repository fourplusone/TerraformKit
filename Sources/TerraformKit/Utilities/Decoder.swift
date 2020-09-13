//
//  File 2.swift
//  
//
//  Created by Matthias Bartelmeß on 13.09.20.
//

import Foundation

class TerraformDecoder : JSONDecoder {
    override init() {
        super.init()
        self.keyDecodingStrategy = .convertFromSnakeCase
    }
}
