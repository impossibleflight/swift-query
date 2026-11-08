import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public enum SelectionMacro {}

extension SelectionMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: Message.notAStruct))
            return []
        }
        guard let model = modelType(of: node) else {
            context.diagnose(Diagnostic(node: node, message: Message.missingModel))
            return []
        }

        let properties = StoredProperties.of(structDecl, in: context, macro: "Selection")
        // A property with an initial value belongs to the row alone, so the initializer leaves it be.
        let selected = properties.filter { !$0.hasInitialValue }
        let assignments = selected.map { "self.\($0.name) = model.\($0.name).snapshotValue" }

        var members: [DeclSyntax] = [
            """
            \(raw: initializerAccess(of: node))init(_ model: \(raw: model)) {
                \(raw: assignments.joined(separator: "\n    "))
            }
            """
        ]
        if identifiesByPersistentModelID(properties) {
            let access = StoredProperties.accessModifier(of: structDecl.modifiers)
            members.append("\(raw: access)var id: PersistentIdentifier { persistentModelID }")
        }
        return members
    }
}

extension SelectionMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }
        let properties = StoredProperties.of(structDecl, in: context, macro: "Selection")
        let identifiable = properties.contains { $0.name == "id" } || identifiesByPersistentModelID(properties)
        let conformances = protocols
            .map(\.trimmedDescription)
            .filter { $0 != "Identifiable" || identifiable }
        guard !conformances.isEmpty else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {}")]
    }
}

private extension SelectionMacro {
    /// The model named by `of:`, written `Model.self`.
    static func modelType(of node: AttributeSyntax) -> String? {
        guard let expression = argument(labeled: "of", in: node) else { return nil }
        if let access = expression.as(MemberAccessExprSyntax.self), access.declName.baseName.tokenKind == .keyword(.self) {
            return access.base?.trimmedDescription
        }
        return expression.trimmedDescription
    }

    /// The modifier on the generated initializer: internal unless `initializer:` asks for more.
    static func initializerAccess(of node: AttributeSyntax) -> String {
        guard let expression = argument(labeled: "initializer", in: node)?.as(MemberAccessExprSyntax.self) else { return "" }
        switch expression.declName.baseName.text {
        case "public": return "public "
        case "package": return "package "
        default: return ""
        }
    }

    static func argument(labeled label: String, in node: AttributeSyntax) -> ExprSyntax? {
        node.arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == label }?.expression
    }

    static func identifiesByPersistentModelID(_ properties: [StoredProperty]) -> Bool {
        properties.contains { $0.name == "persistentModelID" } && !properties.contains { $0.name == "id" }
    }

    enum Message: DiagnosticMessage {
        case notAStruct
        case missingModel

        var message: String {
            switch self {
            case .notAStruct: "@Selection can only be applied to a struct"
            case .missingModel: "@Selection needs the model type, as in @Selection(of: Book.self)"
            }
        }

        var diagnosticID: MessageID {
            switch self {
            case .notAStruct: MessageID(domain: "SwiftQueryMacros", id: "notAStruct")
            case .missingModel: MessageID(domain: "SwiftQueryMacros", id: "missingModel")
            }
        }

        var severity: DiagnosticSeverity { .error }
    }
}
