import Foundation

public indirect enum Type : Equatable {
    case string
    case number
    case bool
    case map(Type)
    case list(Type)
    case set(Type)
    case object([String: Type])
}

extension Type : Decodable {
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let typeName = try container.decode(String.self)
            switch typeName {
            case "string":
                self = Type.string
                return
            case "number":
                self = Type.number
                return
            case "bool":
                self = Type.bool
                return
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown type \(typeName)")
            }
        } catch DecodingError.typeMismatch{
            var container = try decoder.unkeyedContainer()
            let typeName = try container.decode(String.self)
            
            switch typeName {
            case "map":
                self = Type.map(try container.decode(Type.self))
                return
            case "set":
                self = Type.set(try container.decode(Type.self))
                return
            case "list":
                self = Type.set(try container.decode(Type.self))
                return
            case "object":
                self = Type.object(try container.decode([String: Type].self))
                return
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown type \(typeName)")
            }
        }
        
    }
}

public struct Schema : Decodable {
    /// "version" is the schema version, not the provider version
    public let version: Int64
    
    public let block: Block
    
    /// A block representation contains "attributes" and "blockTypes" (which represent nested blocks).
    public struct Block : Decodable {
        /// `attributes` describes any attributes that appear directly inside the
        /// block. Keys in this map are the attribute names.
        public let attributes: [String: Attribute]?
        
        public struct Attribute : Decodable {
            /// `type` is a representation of a type specification
            /// that the attribute's value must conform to.
            public let type: Type
            
            /// `description` is an English-language description of
            /// the purpose and usage of the attribute.
            public let description: String?
            
            /// `optional`, if set to true, specifies that an omitted or null value is permitted.
            public let optional: Bool
            
            /// `computed`, if set to true, indicates that the value comes from the provider rather than the configuration.

            public let computed: Bool
            
            /// `required`, if set to true, specifies that an omitted or null value is not permitted.
            public let required: Bool
            
            /// `sensitive`, if set to true, indicates that the attribute may contain sensitive information.
            public let sensitive: Bool
            
            enum CodingKeys: String, CodingKey {
                case type
                case description
                case optional
                case computed
                case required
                case sensitive
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                
                description = try values.decodeIfPresent(String.self, forKey:.description)
                optional = try values.decodeIfPresent(Bool.self, forKey:.optional) ?? false
                computed = try values.decodeIfPresent(Bool.self, forKey:.computed) ?? false
                required = try values.decodeIfPresent(Bool.self, forKey:.required) ?? false
                sensitive = try values.decodeIfPresent(Bool.self, forKey:.sensitive) ?? false
                
                type = try values.decode(Type.self, forKey: .type)
            }
            
        }

        
        /// `blockTypes" describes any nested blocks that appear directly inside the block. Keys in this map are the names of the blockTypes.
        public let blockTypes: [String: BlockType]?
        
        public struct BlockType : Decodable {
            public let nestingMode: NestingMode
            
            public enum NestingMode : String, Decodable{
                case single
                case list
                case set
                case map
            }
            
            public let block: Block
            public let minItems: Int?
            public let maxItems: Int?
        }
    }
}


/// The top-level object returned by `terraform providers schema -json`
public struct SchemaDescription : Decodable {
    public let formatVersion: String
    
    /// `providerSchemas` describes the provider schemas for all
    /// providers throughout the configuration tree.
    /// keys in this map are the provider type, such as `random`
    public let providerSchemas: [String: ProviderSchema]
    
    public struct ProviderSchema : Decodable {
        
        /// `provider` is the schema for the provider configuration
        public let provider: Schema
        
        /// `data_source_schemas` map the data source type name to the data source's schema
        public let resourceSchemas: [String: Schema]
        
        /// `resourceSchemas` map the resource type name to the resource's schema
        public let dataSourceSchemas: [String: Schema]
        
        enum CodingKeys: String, CodingKey {
            case provider
            case resourceSchemas
            case dataSourceSchemas
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            provider = try values.decode(type(of: provider), forKey:.provider)
            
            resourceSchemas = try values.decodeIfPresent(type(of: resourceSchemas),
                                                         forKey:.resourceSchemas) ?? [:]
            dataSourceSchemas = try values.decodeIfPresent(type(of: dataSourceSchemas),
                                                           forKey:.dataSourceSchemas) ?? [:]
        }
    }

}
