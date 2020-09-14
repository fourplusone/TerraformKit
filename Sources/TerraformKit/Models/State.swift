
/// The complete top-level object returned by `terraform show -json <STATE FILE>`.
public struct State : Decodable{
    
    /// `values` is a values representation object derived from the values in the
    /// state. Because the state is always fully known, this is always complete.
    public let values: Values
    
    public let terraformVersion: String
}
