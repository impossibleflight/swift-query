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

        let access = StoredProperties.accessModifier(of: classDecl.modifiers)
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
        StoredProperties.of(declaration, in: context, macro: "Snapshotable").compactMap { property in
            guard let type = property.type else {
                context.diagnose(Diagnostic(node: property.binding, message: Message.missingType(property.name)))
                return nil
            }
            return StoredProperty(name: property.name, type: type)
        }
    }

    enum Message: DiagnosticMessage {
        case notAClass
        case missingType(String)

        var message: String {
            switch self {
            case .notAClass:
                "@Snapshotable can only be applied to a class"
            case .missingType(let name):
                "@Snapshotable needs an explicit type for '\(name)'"
            }
        }

        var diagnosticID: MessageID {
            switch self {
            case .notAClass: MessageID(domain: "SwiftQueryMacros", id: "notAClass")
            case .missingType: MessageID(domain: "SwiftQueryMacros", id: "missingType")
            }
        }

        var severity: DiagnosticSeverity { .error }
    }
}
