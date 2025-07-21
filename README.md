# swift-query
A simple query language for SwiftData with automatic support for Swift concurrency.

## Usage

```swift
// Query from the main context
let people = Query<Person>()
    .include(#Predicate { $0.age >= 18 } )
    .sortBy(\.age)
    .results(in: modelContainer)
for person in people {
    print("Adult: \(person.name), age \(person.age)")
}


// Or a background context
Task.detached {
    await modelContainer.queryActor().perform { _ in
        let people = Query<Person>()
            .include(#Predicate { $0.age >= 18 } )
            .sortBy(\.age)
            .results()
        
        for person in people {
            person.age += 1
        }
    }
}    
```

### Building Queries

Queries are an expressive layer on top of SwiftData that allow us to quickly build 
complex fetch decriptors by successively applying refinements. The resulting query can 
be saved for reuse or performed immediately. 

Queries can be initialized explicitly, but `PersistentModel` has also been extended 
so the result type can be inferred from the context:

```swift    
let query = Person.include(#Predicate { $0.name == "Jack" })
```

#### Fetching all objects

The simplest query has no filters at all, and returns all objects when performed:

```swift
Query<Person>()
Person.query()
``` 

#### Narrowing a query

Queries can be narrowed by selecting or excluding candidate objects using predicates:

```swift
Person.include(#Predicate { $0.name == "Jack" })
Person.exclude(#Predicate { $0.age > 25 })
```

#### Creating compound refinements

Multiple `include()` and `exclude()` calls create compound predicates using AND logic, allowing you to build complex filters:

```swift
// Find adult Jacks who are active
Person.include(#Predicate { $0.age >= 18 })
      .include(#Predicate { $0.name == "Jack" })
      .exclude(#Predicate { $0.isInactive })
```

This creates a compound predicate equivalent to:
```swift
#Predicate<Person> { person in
    person.age >= 18 && person.name == "Jack" && !person.isInactive
}
```

#### Ordering results

Queries allow their results to be ordered:

```swift
Person.sortBy(\.age, order: .reverse)
``` 

Successive orderings are cumulative. The following will order by age, then by name within 
age groups:

```swift
Person
    .sortBy(\.age)
    .sortBy(\.name)
```

Orderings can easily be reversed. The following revserses all previous orderings:

```swift
Person
    .sortBy(\.age)
    .sortBy(\.name)
    .reverse()
```

This allows for functionality like toggling the direction of a complex sort.

#### Chaining refinements

The result of refining a query is another query, so refinements can be chained indefinitely:

```swift
Person
    .include(#Predicate { $0.name == "Jack" })
    .exclude(#Predicate { $0.age > 25 })
    .sortBy(\.name)
```

#### Limiting the size of the result set of a query

Often we want to fetch just a slice of a full result set. We can pass a range representing
indices of the first and last elements we want to the subscript on a query and get a new query that 
will only fetch that part of the result set:

```swift
Person.sortBy(\.age)[0..<5]
```

The query above will fetch the first five people. The next query would fetch persons 6-10:

```swift
Person.sortBy(\.age)[5..<10]
```

It's even possible to get an arbitrary sampling of five people. Since no ordering has
been applied to this query, we'll just get the first five results:

```swift
Person[0..<5]
```

### Fetching results

Queries are just descriptions of how to fetch objects from a context. To make them 
useful, we want to be able to perform them. When fetching results on the main actor,
we pass in our model container and SwiftQuery will use the container's main context.

#### Fetching one result

Often we just want to fetch a single result.
 
```swift
let jillQuery = Person.include(#Predicate { $0.name == "Jill" })

let jill = jillQuery.first(in: modelContainer)
let lastJill  = jillQuery.last(in: modelContainer)
```

#### Fetching all results

When we want to fetch all query results in memory, we can use `results`:
 
```swift
let notJillQuery = Person.exclude(#Predicate { $0.name == "Jill" })
let notJills = notJillQuery.results(in: modelContainer)
```

#### Lazy results

Sometimes we want a result that is lazily evaluated. For these cases we can get a 
`FetchResultsCollection` using `fetchedResults`:

```swift
let lazyAdults = Person
    .include(#Predicate { $0.age > 25 })
    .fetchedResults(in: modelContainer)
```

#### Fetching or creating objects matching a query

A common pattern in Core Data (and so in SwiftData), is to want to fetch an object 
based on a set of filters, or create a new one by default in the case that object 
does not yet exist. This is easy with SwiftQuery using `findOrCreate`:

```swift
let jill = Person
    .include(#Predicate { $0.name == "Jill" })
    .findOrCreate(in: container) {
        Person(name: "Jill")
    }
```

### Performing queries in a concurrent context

Where SwiftQuery really shines is it's automatic support for performing queries
in a concurrent context. The current isolation context is passed in to each function
that performs a query, so if you have a custom model actor, you can freely perform
queries inside the actor:

```swift
@ModelActor
actor MyActor {
    func promoteJill() throws {
        if let jill = Person
            .include(#Predicate { $0.name == "Jill" })
            .first() 
        {
            jill.isPromoted = true
            try modelContext.save()
        }
    }
}
```

We also expose an async `perform` functions on a SwiftQuery's default actor that allow you to 
implicitly use `QueryActor` to run queries:

```swift
await modelContainer.queryActor().perform { _ in
    let allJills = Person
        .include(#Predicate { $0.name == "Jill" })
        .results()
    
    // Process Jills within the actor context
    for jill in allJills {
        print("Found Jill: \(jill.name)")
    }
}
``` 

Or, to return a value:

```swift
let count = await modelContainer.queryActor().perform { _ in
    Query<Person>()
    .include(#Predicate { $0.age >= 18 } )
    .count()
} 
```

Note that models cannot be returned out of the actor's isolation context using this function; 
only `Sendable` values can be transported across the boundary. This means the compiler 
effectively makes it impossible to use the models incorrectly in a multi-threaded context, 
thus guaranteeing the SwiftData concurrency contract at compile time.     

## Installation

You can add SwiftQuery to an Xcode project by adding it to your project as a package.

> https://github.com/impossibleflight/swift-query

If you want to use SwiftQuery in a [SwiftPM](https://swift.org/package-manager/) project, it's as
simple as adding it to your `Package.swift`:

``` swift
dependencies: [
  .package(url: "https://github.com/impossibleflight/swift-query", from: "0.1.0")
]
```

And then adding the product to any target that needs access to the library:

```swift
.product(name: "SwiftQuery", package: "swift-query"),
```

## License

swift-query is licensed under the MIT license. See [LICENSE](LICENSE)

## Acknowledgements

Inspired by [QueryKit](https://github.com/QueryKit/QueryKit)
