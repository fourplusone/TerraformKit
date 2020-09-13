public struct Expression : Decodable{
    /// "constant_value" is set only if the expression contains no references to
    /// other objects, in which case it gives the resulting constant value. This is
    /// mapped as for the individual values in a value representation.
    public let constantValue: String?
    
    
    /// Alternatively, "references" will be set to a list of references in the
    /// expression. Multi-step references will be unwrapped and duplicated for each
    /// significant traversal step, allowing callers to more easily recognize the
    /// objects they care about without attempting to parse the expressions.
    /// Callers should only use string equality checks here, since the syntax may
    /// be extended in future releases.
    public let references: [String]
}

public indirect enum BlockExpression : Decodable {
    case expression(_: Expression)
    case single(_: BlockExpression)
    case list(_: [BlockExpression])
    case map(_: [String: BlockExpression])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let expression = try? container.decode(Expression.self) {
            self = .expression(expression)
        } else if let single = try? container.decode(BlockExpression.self) {
            self = .single(single)
        } else if let list = try? container.decode(Array<BlockExpression>.self) {
            self = .list(list)
        } else if let map = try? container.decode(Dictionary<String, BlockExpression>.self) {
            self = .map(map)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "BlockExpression value cannot be decoded")
        }
    }
}

public struct Configuration : Decodable {
    /// "providerConfigs" describes all of the provider configurations throughout
    /// the configuration tree, flattened into a single map for convenience since
    /// provider configurations are the one concept in Terraform that can span
    /// across module boundaries.
    public let providerConfigs: [String: ProviderConfig]
    
    public struct ProviderConfig : Decodable {
        /// `name` is the name of the provider without any alias
        public let name: String

        /// `alias` is the alias set for a non-default configuration, or unset for
        /// a default configuration.
        public let alias: String?

        /// `moduleAddress` is included only for provider configurations that are
        /// declared in a descendent module, and gives the opaque address for the
        /// module that contains the provider configuration.
        public let moduleAddress: String?

        /// `expressions` describes the provider-specific content of the
        /// configuration block, as a block expressions representation (see section
        /// below).
        public let expressions: [String: BlockExpression]
    }
    
    /// "rootModule" describes the root module in the configuration, and serves
    /// as the root of a tree of similar objects describing descendent modules.
    public let rootModule: ModuleConfiguration
    
    public struct ModuleConfiguration : Decodable {
        public struct Property : Decodable {
            public let expression: Expression
            public let sesitive: Bool
        }
        
        /// `outputs` describes the output value configurations in the module.
        /// Property names here are the output value names
        public let outputs: [String: Property]
    }
    
    /// `resources` describes the `resource` and `data` blocks in the module
    /// configuration.
    public let resources: [ResourceConfiguration]
    
    public struct ResourceConfiguration : Decodable {
        // `address` is the opaque absolute address for the resource itself.
        public let address: String
        
        /// "mode", "type", and "name" have the same meaning as for the resource
        /// portion of a value representation.
        
        public let mode: Mode
        public let type: String
        public let name: String
        
        /// `providerConfigKey` is the key into `providerConfigs` (shown
        /// above) for the provider configuration that this resource is
        /// associated with.
        public let providerConfigKey: String
        
        
        public struct Provisioner : Decodable {
            public let type: String
            /// `expressions` describes the provisioner configuration
            public let expressions: [String: BlockExpression]
        }
        
        /// `provisioners` is an optional field which describes any provisioners.
        /// Connection info will not be included here.
        public let provisioners: [Provisioner]
        
        /// `expressions` describes the resource-type-specific content of the
        /// configuration block.
        public let expressions: [String: BlockExpression]

        // "schema_version" is the schema version number indicated by the
        // provider for the type-specific arguments described in "expressions".
        public let schema_version: Int64

        /// `countExpression` and `forEachExpression` describe the expressions
        /// given for the corresponding meta-arguments in the resource
        /// configuration block. These are omitted if the corresponding argument
        /// isn't set.
        public let countExpression: Expression
        public let forEachExpression: Expression
    }
    
    /// `moduleCalls` describes the "module" blocks in the module. During
    /// evaluation, a module call with count or for_each may expand to multiple
    /// module instances, but in configuration only the block itself is
    /// represented.
    /// Key is the module call name chosen in the configuration.
    public let moduleCalls: [String: ModuleCall]
    
    public struct ModuleCall : Decodable {
        /// `resolvedSource` is the resolved source address of the module, after
        /// any normalization and expansion. This could be either a
        /// go-getter-style source address or a local path starting with "./" or
        /// "../". If the user gave a registry source address then this is the
        /// final location of the module as returned by the registry, after
        //// following any redirect indirection.
        public let resolvedSource: String

        /// `expressions` describes the expressions for the arguments within the
        /// block that correspond to input variables in the child module.
        public let expressions: [String: BlockExpression]

        /// `countExpression` and `forEachExpression` describe the expressions
        /// given for the corresponding meta-arguments in the resource
        /// configuration block. These are omitted if the corresponding argument
        /// isn't set.
        public let countExpression: Expression
        public let forEachExpression: Expression

        /// "module" is a representation of the configuration of the child module
        /// itself, using the same structure as the "root_module" object,
        /// recursively describing the full module tree.
        public let module: Module
    }
}
