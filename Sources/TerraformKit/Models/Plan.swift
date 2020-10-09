//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 13.09.20.
//

import Foundation


/// A plan consists of a prior state, the configuration that is being applied to that state, and the set of changes Terraform plans to make to achieve that.
/// For ease of consumption by callers, the plan representation includes a partial representation of the values in the final state (using a value representation), allowing callers to easily analyze the planned outcome using similar code as for analyzing the prior state.
public struct Plan : Decodable {
    
    var source : Data!
    
    /// `priorState` is a representation of the state that the configuration is
    /// being applied to, using the state representation described above.
    public let priorState : State?
    
    /// `configuration` is a representation of the configuration being applied to the
    /// prior state, using the configuration representation described above.
    public let configuration: Configuration
    
    /// A sub-object of plan output that describes a parsed Terraform configuration.
    public struct Configuration : Decodable {
        
        /// A sub-object of a configuration representation that describes an unevaluated expression.
        public struct Expression : Decodable{
            /// `constantValue` is set only if the expression contains no references to
            /// other objects, in which case it gives the resulting constant value. This is
            /// mapped as for the individual values in a value representation.
            public let constantValue: String?
            
            
            /// Alternatively, `references` will be set to a list of references in the
            /// expression. Multi-step references will be unwrapped and duplicated for each
            /// significant traversal step, allowing callers to more easily recognize the
            /// objects they care about without attempting to parse the expressions.
            /// Callers should only use string equality checks here, since the syntax may
            /// be extended in future releases.
            public let references: [String]?
        }

        /// A sub-object of a configuration representation that describes the expressions nested inside a block.
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
        
        /// `providerConfigs` describes all of the provider configurations throughout
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
        
        /// `rootModule` describes the root module in the configuration, and serves
        /// as the root of a tree of similar objects describing descendent modules.
        public let rootModule: ModuleConfiguration
        
        public struct ModuleConfiguration : Decodable {
            
            public struct Property : Decodable {
                public let expression: Expression
                public let sensitive: Bool
                
                private enum CodingKeys : String, CodingKey {
                    case expression
                    case sensitive
                }
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    expression = try container.decode(Expression.self,
                                                      forKey:.expression)
                    sensitive = try container.decodeIfPresent(Bool.self,
                                                              forKey: .sensitive) ?? false
                }
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
            
            /// `mode`, `type`, and `name` have the same meaning as for the resource
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

            /// `schemaVersion` is the schema version number indicated by the
            /// provider for the type-specific arguments described in "expressions".
            public let schemaVersion: Int64

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

            /// `module` is a representation of the configuration of the child module
            /// itself, using the same structure as the "root_module" object,
            /// recursively describing the full module tree.
            public let module: Module
        }
    }

    
    /// `plannedValues` is a description of what is known so far of the outcome in
    /// the standard value representation, with any as-yet-unknown values omitted.
    public let plannedValues : Values

    /// `proposedUnknown` is a representation of the attributes, including any
    /// potentially-unknown attributes. Each value is replaced with "true" or
    /// "false" depending on whether it is known in the proposed plan.
    public let proposedUnknown: Values?
    
    /// `variables` is a representation of all the variables provided for the given
    /// plan. This is structured as a map similar to the output map so we can add
    /// additional fields in later.
    public let variables: [String: Variable]
    
    public struct Variable : Decodable {
        public let value: AnyDecodable
    }
    
    /// Each element of this array describes the action to take
    /// for one instance object. All resources in the
    /// configuration are included in this list.
    public let resourceChanges: [ResourceChange]
    
    ///A  `change`  describes the change that will be made to the indicated object.
    public struct Change<Values>: Decodable where Values : Decodable {
        
        public enum Action : String, Decodable {
            case noOp = "no-op"
            case create
            case read
            case update
            case delete
        }
        
        /// `actions` are the actions that will be taken on the object selected by the
        /// properties below.
        /// Valid actions values are:
        ///    ["no-op"]
        ///    ["create"]
        ///    ["read"]
        ///    ["update"]
        ///    ["delete", "create"]
        ///    ["create", "delete"]
        ///    ["delete"]
        /// The two "replace" actions are represented in this way to allow callers to
        /// e.g. just scan the list for "delete" to recognize all three situations
        /// where the object will be deleted, allowing for any new deletion
        /// combinations that might be added in future.
        public let actions: [Action]

        /// `before` and `after` are representations of the object value both before
        /// and after the action. For ["create"] and ["delete"] actions, either
        /// "before" or "after" is unset (respectively). For ["no-op"], the before and
        /// after values are identical. The `after` value will be incomplete if there
        /// are values within it that won't be known until after apply.
        public let before: Values?
        
        /// see `before`
        public let after: Values?
    }
    
    public struct ResourceChange : Decodable {
        /// "address" is the full absolute address of the resource instance this
        /// change applies to, in the same format as addresses in a value
        /// representation
        public let address: String
        
        /// "moduleAddress", if set, is the module portion of the above address.
        /// Omitted if the instance is in the root module.
        public let moduleAddress: String?
        
        public let mode : Mode
        public let type : String
        public let name : String
        
        /// If the count or for_each meta-arguments are set for this resource, the
        /// additional key "index" is present to give the instance index key. This
        /// is omitted for the single instance of a resource that isn't using count
        /// or for_each.
        public let index: Int64?
        
        /// `deposed`, if set, indicates that this action applies to a "deposed"
        /// object of the given instance rather than to its "current" object.
        /// Omitted for changes to the current object. "address" and "deposed"
        /// together form a unique key across all change objects in a particular
        /// plan. The value is an opaque key representing the specific deposed
        /// object.
        public let deposed: String?
        
        /// `change` describes the change that will be made to the indicated
        /// object. The <change-representation> is detailed in a section below.
        public let change: Change<Values>
    }
    
    /// `Change` describes the change that will be made to the indicated output
    /// value, using the same representation as for resource changes except
    /// that the only valid actions values are:
    ///   ["create"]
    ///   ["update"]
    ///   ["delete"]
    /// In the Terraform CLI 0.12.0 release, Terraform is not yet fully able to
    /// track changes to output values, so the actions indicated may not be
    /// fully accurate, but the "after" value will always be correct.
    public let outputChanges : [String: Change<AnyDecodable>]
}
