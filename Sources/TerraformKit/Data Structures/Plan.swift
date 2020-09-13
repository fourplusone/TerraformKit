//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 13.09.20.
//

import Foundation

public struct Plan : Decodable {
    
    /// `priorState` is a representation of the state that the configuration is
    /// being applied to, using the state representation described above.
    public let priorState : State?
    
    /// `configuration` is a representation of the configuration being applied to the
    /// prior state, using the configuration representation described above.
    public let configuration: Configuration
    
    /// "plannedValues" is a description of what is known so far of the outcome in
    /// the standard value representation, with any as-yet-unknown values omitted.
    public let plannedValues : Values

    /// proposedUnknown is a representation of the attributes, including any
    /// potentially-unknown attributes. Each value is replaced with "true" or
    /// "false" depending on whether it is known in the proposed plan.
    public let proposedUnknown: Values?
    
    /// "variables" is a representation of all the variables provided for the given
    /// plan. This is structured as a map similar to the output map so we can add
    /// additional fields in later.
    public let variables: [String: Variable]?
    
    public struct Variable : Decodable {
        public let value: AnyDecodable
    }
    
    /// Each element of this array describes the action to take
    /// for one instance object. All resources in the
    /// configuration are included in this list.
    public let resourceChanges: [ResourceChange]?
    
    public struct Change: Decodable {
        /// "actions" are the actions that will be taken on the object selected by the
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
        public enum Action : String, Decodable {
            case noOp = "no-op"
            case create
            case read
            case update
            case delete
        }
        
        public let actions: [Action]

        /// "before" and "after" are representations of the object value both before
        /// and after the action. For ["create"] and ["delete"] actions, either
        /// "before" or "after" is unset (respectively). For ["no-op"], the before and
        /// after values are identical. The "after" value will be incomplete if there
        /// are values within it that won't be known until after apply.
        public let before: Values?
        public let after: Values
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
        public let change: Change
    }
    
    public let outputChanges : [String: OutputChange]?
    public struct OutputChange : Decodable{
        /// "change" describes the change that will be made to the indicated output
        /// value, using the same representation as for resource changes except
        /// that the only valid actions values are:
        ///   ["create"]
        ///   ["update"]
        ///   ["delete"]
        /// In the Terraform CLI 0.12.0 release, Terraform is not yet fully able to
        /// track changes to output values, so the actions indicated may not be
        /// fully accurate, but the "after" value will always be correct.
        public let change: Change
    }
}
