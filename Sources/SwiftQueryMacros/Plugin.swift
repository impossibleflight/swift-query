import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftQueryMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SelectionMacro.self,
    ]
}
