import Foundation

/// Marks a list item as a GFM task item; value is the checked state.
public enum TaskItemAttribute: AttributedStringKey {
    public typealias Value = Bool
    public static let name = "fecni.taskItem"
}

public extension AttributeScopes {
    struct FecniAttributes: AttributeScope {
        public let taskItem: TaskItemAttribute
    }
    var fecni: FecniAttributes.Type { FecniAttributes.self }
}

public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.FecniAttributes, T>
    ) -> T { self[T.self] }
}
