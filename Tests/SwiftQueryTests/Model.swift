import SwiftData

@Model
final class Person {
    var name: String = ""
    var age: Int = 0

    init(
        name: String = "",
        age: Int = 0
    ) {
        self.name = name
        self.age = age
    }
}

extension Person: CustomStringConvertible {
    var description: String {
        return "Person(name: \(name), age: \(age))"
    }
}
