import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public enum SnapshotableMacro {}

extension SnapshotableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: Message.notAClass))
            return []
        }

        let access = accessModifier(of: classDecl)
        let properties = storedProperties(of: declaration, in: context)
        let hasStoredID = properties.contains { $0.name == "id" }

        var members: [String] = ["\(access)let persistentModelID: PersistentIdentifier"]
        members += properties.map { "\(access)let \($0.name): Snapshotted<\($0.type)>" }
        if !hasStoredID {
            members.append("\(access)var id: PersistentIdentifier { persistentModelID }")
        }
        // A struct's memberwise initializer is never more than internal, so a snapshot that is
        // visible outside its module gets an explicit one at the same level.
        if !access.isEmpty {
            var parameters = ["persistentModelID: PersistentIdentifier"]
            parameters += properties.map { "\($0.name): Snapshotted<\($0.type)>" }
            var assignments = ["self.persistentModelID = persistentModelID"]
            assignments += properties.map { "self.\($0.name) = \($0.name)" }
            members.append(
                """
                \(access)init(\(parameters.joined(separator: ", "))) {
                        \(assignments.joined(separator: "\n        "))
                    }
                """
            )
        }

        var arguments = ["persistentModelID: persistentModelID"]
        arguments += properties.map { "\($0.name): \($0.name).snapshotValue" }

        return [
            """
            \(raw: access)struct Snapshot: Identifiable, Hashable, Sendable {
                \(raw: members.joined(separator: "\n    "))
            }
            """,
            """
            \(raw: access)var snapshot: Snapshot {
                Snapshot(
                    \(raw: arguments.joined(separator: ",\n        "))
                )
            }
            """,
        ]
    }
}

extension SnapshotableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self), !protocols.isEmpty else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): SnapshotConvertible {}")]
    }
}

private extension SnapshotableMacro {
    struct StoredProperty {
        let name: String
        let type: String
    }

    static func storedProperties(
        of declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) -> [StoredProperty] {
        declaration.memberBlock.members.compactMap { member in
            guard
                let variable = member.decl.as(VariableDeclSyntax.self),
                isStored(variable)
            else { return nil }

            guard variable.bindings.count == 1, let binding = variable.bindings.first else {
                context.diagnose(Diagnostic(node: variable, message: Message.multipleBindings))
                return nil
            }
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
            guard let type = binding.typeAnnotation?.type else {
                context.diagnose(Diagnostic(node: binding, message: Message.missingType(pattern.identifier.text)))
                return nil
            }
            return StoredProperty(name: pattern.identifier.text, type: type.trimmedDescription)
        }
    }

    /// The modifier the generated declarations carry so they are as visible as the model: `public`
    /// for a public or open class, `package` for a package one, and nothing otherwise. A private or
    /// file-private class keeps internal members, which its own scope already confines.
    static func accessModifier(of classDecl: ClassDeclSyntax) -> String {
        for modifier in classDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open): return "public "
            case .keyword(.package): return "package "
            default: continue
            }
        }
        return ""
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

    enum Message: DiagnosticMessage {
        case notAClass
        case multipleBindings
        case missingType(String)

        var message: String {
            switch self {
            case .notAClass:
                "@Snapshotable can only be applied to a class"
            case .multipleBindings:
                "@Snapshotable needs one property per declaration"
            case .missingType(let name):
                "@Snapshotable needs an explicit type for '\(name)'"
            }
        }

        var diagnosticID: MessageID {
            switch self {
            case .notAClass: MessageID(domain: "SwiftQueryMacros", id: "notAClass")
            case .multipleBindings: MessageID(domain: "SwiftQueryMacros", id: "multipleBindings")
            case .missingType: MessageID(domain: "SwiftQueryMacros", id: "missingType")
            }
        }

        var severity: DiagnosticSeverity { .error }
    }
}
