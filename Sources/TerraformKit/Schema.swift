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

public struct Attribute : Decodable {
    public let type: Type
    public let description: String?
    public let optional: Bool
    public let computed: Bool
    public let required: Bool
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

public enum NestingMode : String, Decodable{
    case single
    case list
    case set
    case map
}

public struct BlockType : Decodable {
    public let nestingMode: NestingMode
    public let block: Block
    public let minItems: Int?
    public let maxItems: Int?
}

public struct Block : Decodable {
    public let attributes: [String: Attribute]?
    public let blockTypes: [String: BlockType]?
}

public struct Schema : Decodable {
    public let version: Int64
    public let block: Block
}

public struct ProviderSchema : Decodable {
    public let provider: Schema
    public let resourceSchemas: [String: Schema]
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

public struct SchemaDescription : Decodable{
    public let formatVersion: String
    public let providerSchemas: [String: ProviderSchema]
}
