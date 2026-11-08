import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// A stored property of a type a macro is attached to, as far as its syntax reveals.
struct StoredProperty {
    let name: String
    let hasInitialValue: Bool
    /// The binding, for diagnostics.
    let binding: PatternBindingSyntax
}

/// The stored-property reading of a declaration: instance properties that are neither
/// computed nor `@Transient`, one binding per declaration.
enum StoredProperties {
    static func of(
        _ declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext,
        macro: String
    ) -> [StoredProperty] {
        declaration.memberBlock.members.compactMap { member in
            guard
                let variable = member.decl.as(VariableDeclSyntax.self),
                isStored(variable)
            else { return nil }

            guard variable.bindings.count == 1, let binding = variable.bindings.first else {
                context.diagnose(Diagnostic(node: variable, message: Message.multipleBindings(macro)))
                return nil
            }
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
            return StoredProperty(
                name: pattern.identifier.text,
                hasInitialValue: binding.initializer != nil,
                binding: binding
            )
        }
    }

    static func isStored(_ variable: VariableDeclSyntax) -> Bool {
        let isStatic = variable.modifiers.contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
        let isTransient = variable.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Transient"
        }
        guard !isStatic, !isTransient else { return false }

        guard let accessors = variable.bindings.first?.accessorBlock?.accessors else { return true }
        switch accessors {
        case .getter:
            return false
        case .accessors(let list):
            return list.allSatisfy { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet): true
                default: false
                }
            }
        }
    }

    /// The modifier generated declarations carry to be as visible as the type: `public ` for a
    /// public or open type, `package ` for a package one, and nothing otherwise. A private or
    /// file-private type keeps internal members, which its own scope already confines.
    static func accessModifier(of modifiers: DeclModifierListSyntax) -> String {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open): return "public "
            case .keyword(.package): return "package "
            default: continue
            }
        }
        return ""
    }

    enum Message: DiagnosticMessage {
        case multipleBindings(String)

        var message: String {
            switch self {
            case .multipleBindings(let macro):
                "@\(macro) needs one property per declaration"
            }
        }

        var diagnosticID: MessageID {
            switch self {
            case .multipleBindings: MessageID(domain: "SwiftQueryMacros", id: "multipleBindings")
            }
        }

        var severity: DiagnosticSeverity { .error }
    }
}
