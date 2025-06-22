# swift-query
A simple query language for Swift Data with automatic support for Swift concurrency.

## Usage

```swift
// Main context
let people = Query<Person>()
    .filter(#Predicate { $0.age >= 18 } )
    .sort(.init(\.age))
    .results(in: modelContainer)

// Or a background context
Task.detached {
    let people = await modelContainer.perform {
        Query<Person>()
            .filter(#Predicate { $0.age >= 18 } )
            .sort(.init(\.age))
            .results()
    }
}    
```

### Building Queries

Queries are an expressive layer on top of Swift Data that allow us to quickly build 
complex fetch decriptors by successively applying filters. The resulting query can 
be saved for reuse or performed immediately. 

Queries can be initialized explicitly, but `PersistentModel` has also been extended 
so the result type can be inferred from the context:

```swift    
    let query = Person.filter(#Predicate { \.name == "John" })
```

#### Fetching all objects

The simplest query has no filters at all, and returns all objects when performed:

```swift
Query<Person>()
``` 

#### Narrowing a query

Queries can be narrowed by selecting or excluding candidate objects by predicate:

```swift
Person.filter(#Predicate { \.name == "John" })
Person.exclude(#Predicate { \.age > 25 })
```

#### Ordering results

Queries allow their results to be ordered:

```swift
Person.
    .sortBy(.init(\.age, order: .reverse))
``` 

Successive orderings are appended. The following will order by age, then, within 
age groups, by name:

```swift
Person.
    .sortBy(.init(\.age))
    .sortBy(.init(\.name))
```

Orderings can easily be reversed. The following revserses all previous orderings:

```swift
Person.
    .sortBy(.init(\.age))
    .sortBy(.init(\.name))
    .reversed()
```

This allows for functionality like toggling the direction of a complex sort.

#### Chaining refinements

The result of refining a query is another query, so they can be chained indefinitely:

```swift
Person
    .filter(#Predicate { \.name == "John" })
    .exclude(#Predicate { \.age > 25 })
    .sortBy(.init(\.name))
```

#### Limiting a query

Often we want to fetch just a slice of a full result set. We can pass a range representing
`fetchOffset` and `fetchLimit` to the subscript on a query and get a new query that 
will only fetch that part of the result set:

```swift
terriesQuery[0..<5]
```

The query above will fetch Terries 1-5. The next query would fetch Terries 6-10:

```swift
terriesQuery[5..<10]
```

### Fetching results

Queries are just descriptions of how to fetch objects from a context. To make them 
useful, we want to be able to perform them. When fetching results on the main actor,
we pass in our model container and SwiftQuery will use the container's 'main context.

#### Fetching one result

Often we just want 
 
```swift
let terryQuery = Person.filter(#Predicate { \.name == "Terry" })

let terry = terryQuery.first(in: modelContainer)
let lastTerry  = terryQuery.last(in: modelContainer)
```

#### Fetching all results

When we want to fetch all query results in memory, we can use `results`:
 
```swift
let notTerryQuery = Person.exclude(#Predicate { \.name == "Terry" })
let notTerries = notTerryQuery.results(in: modelContainer)
```

#### Lazy results

Sometimes we want a result that is lazily evaluated. For these cases we can get a 
`FetchResultsCollection` using `fetchedResults`:

```swift
let lazyAdults = Person
    .filter(#Predicate { \.age > 25 })
    .fetchedResults(in: modelContainer)
```

#### Fetching or creating objects matching a query

A common pattern in Core Data (and so in Swift Data), is to want to fetch an object 
based on a set of filters, or create a new one by default in the case that object 
does not yet exist. This is easy with SwiftQuery using `findOrCreate`:

```swift
let terry = Person
    .filter(#Predicate { \.name == "Terry" })
    .findOrCreate(in: container) {
        Person(name: "Terry")
    }
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
    func promoteTerry() throws {
        if let terry = Person
            .filter(#Predicate { \.name == "Terry" })
            .first() 
        {
            terry.isPromoted = true
            try modelContext.save()
        }
    }
}
```
We also expose async functions on `ModelContainer` that allow you to implicitly use our own
`QueryActor` to run queries:

```swift
let allTerries = try await modelContainer.perform {
    Person
        .filter(#Predicate { \.name == "Terry" })
        .results()
}
``` 

You can of course use this model actor explicitly in a task:

```swift
Task {
    let actor = QueryActor(modelContainer: myModelContainer)
    let allTerries = try await Person
        .filter(#Predicate { \.name == "Terry" })
        .results(isolation: actor)
}
```


## TODO
- Tests

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
.product(name: "SwiftQuery", package: "swift-squery"),
```

## License

swift-query is licensed under the MIT license. See [LICENSE](LICENSE)

## Acknowledgements

Inspired by [QueryKit](https://github.com/QueryKit/QueryKit)
