@propertyWrapper
struct BoundInteger<Storage> where Storage: BinaryInteger {
    public let range: ClosedRange<Storage>
    public var _value: Storage
    
    var wrappedValue: Int {
        get { Int(_value) }
        set {
            _value = Storage(newValue)
            precondition(range ~= _value)
        }
    }
    
    var isAtUpperLimit: Bool { _value == range.upperBound }
    
    init(wrappedValue: Storage, range: ClosedRange<Storage>) {
        precondition(range ~= wrappedValue)
        self.range = range
        self._value = wrappedValue
    }
    
    init(wrappedValue: Storage, range: Range<Storage>) {
        precondition(range.lowerBound < range.upperBound - 1)
        self.init(wrappedValue: wrappedValue, range: ClosedRange(uncheckedBounds: (range.lowerBound, range.upperBound - 1)))
    }
}
