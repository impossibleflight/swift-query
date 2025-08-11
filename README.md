# swift-query
[![CI](https://github.com/impossibleflight/swift-query/actions/workflows/swift.yml/badge.svg)](https://github.com/impossibleflight/swift-query/actions)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fimpossibleflight%2Fswift-query%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/impossibleflight/swift-query)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fimpossibleflight%2Fswift-query%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/impossibleflight/swift-query)


A simple query language for SwiftData with automatic support for Swift concurrency.

## What is SwiftQuery?

The library provides an easy-to-use, modifier-like syntax that can be used to build 
reusable SwiftData queries. These queries can then be executed from either the 
`MainActor` or safely from a background context within any `ModelActor`. 

SwiftData's `Query` type provides a similar ability to build queries, but unlike 
that type, the queries that are built using SwiftQuery are usable from anywhere—
not just from within the SwiftUI environment. This lets us use saved queries from
view models, reducers, background processes, etc..

The correct use of queries in a concurrency environment is built into the 
library, and enforced at compile time, making it painless to adopt best practices.
 

## Usage

```swift
// Query from the main context
let people = try Query<Person>()
    .include(#Predicate { $0.age >= 18 } )
    .sortBy(\.age)
    .results(in: modelContainer)
for person in people {
    print("Adult: \(person.name), age \(person.age)")
}


// Or a background context
Task.detached {
    let actor = modelContainer.createQueryActor()
    await actor.perform { _ in
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
complex fetch descriptors by successively applying refinements. The resulting query can 
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

#### Prefetching relationships

To improve performance when you know you'll need related objects, you can prefetch relationships to reduce database trips:

```swift
// Prefetch a single relationship
let ordersWithCustomers = Order
    .include(#Predicate { $0.status == .active })
    .prefetchRelationship(\.customer)

// Prefetch multiple relationships
let ordersWithDetails = Order
    .prefetchRelationship(\.customer)
    .prefetchRelationship(\.items)
```

#### Fetching specific properties

To reduce memory usage, you can fetch only specific properties instead of full objects:

```swift
// Fetch only specific properties for better performance
let lightweightPeople = Person.fetchKeyPaths(\.name, \.age)
```

### Executing queries

Queries are just descriptions of how to fetch objects from a context. To make them 
useful, we want to be able to perform them. When fetching results on the main actor,
we pass in our model container and SwiftQuery will use the container's main context.

#### Fetching one result

Often we just want to fetch a single result.
 
```swift
let jillQuery = Person.include(#Predicate { $0.name == "Jill" })

let jill = try jillQuery.first(in: modelContainer)
let lastJill  = try jillQuery.last(in: modelContainer)
```
Or any result:

```swift
let anyone = try Person.any(in: modelContainer)
```


#### Fetching all results

When we want to fetch all query results in memory, we can use `results`:
 
```swift
let notJillQuery = Person.exclude(#Predicate { $0.name == "Jill" })
let notJills = try notJillQuery.results(in: modelContainer)
```

#### Lazy results

Sometimes we want a result that is lazily evaluated. For these cases we can get a 
`FetchResultsCollection` using `fetchedResults`:

```swift
let lazyAdults = try Person
    .include(#Predicate { $0.age > 25 })
    .fetchedResults(in: modelContainer)
```

#### Fetching or creating objects matching a query

A common pattern in Core Data (and so in SwiftData), is to want to fetch an object 
based on a set of filters, or create a new one by default in the case that object 
does not yet exist. This is easy with SwiftQuery using `findOrCreate`:

```swift
let jill = try Person
    .include(#Predicate { $0.name == "Jill" })
    .findOrCreate(in: container) {
        Person(name: "Jill")
    }
```

#### Deleting objects

We can delete just the objects matching a refined query:

```swift
try Person
    .include(#Predicate { $0.name == "Jill" })
    .delete(in: container)
```

Or we can delete every record of a particular type:

```swift
try Query<Person>().delete(in: container)
try Person.deleteAll(in: container)
```

`PersistentModel.deleteAll` is equivalent to deleting with an empty query.

### Async fetches

Where SwiftQuery really shines is its automatic support for performing queries
in a concurrency environment. The current isolation context is passed in to each function
that performs a query, so if you have a custom model actor, you can freely perform
queries and operate on the results inside the actor:

```swift
@ModelActor
actor MyActor {
    func promoteJill() throws {
        let jill = Person
            .include(#Predicate { $0.name == "Jill" })
            .findOrCreate {
                Person(name: "Jill")
            }
        jill.isPromoted = true
        try modelContext.save()
    }
}
```

We also expose async `perform` functions on SwiftQuery's default actor that allow you to 
implicitly use `QueryActor` to run queries:

```swift
await modelContainer.createQueryActor().perform { _ in
    let allJills = Person
        .include(#Predicate { $0.name == "Jill" })
        .results()
    
    // Process Jills within the actor context
    for jill in allJills {
        print("Found Jill: \(jill.name)")
    }
}
``` 

The results remain inside the actor's isolation
domain so can be safely used within the closure. 

If we need to produce a side effect for the query, we can return a value:

```swift
let count = await modelContainer.createQueryActor().perform { _ in
    Query<Person>()
    .include(#Predicate { $0.age >= 18 } )
    .count()
} 
```

> Note:  Models cannot be returned out of the actor's isolation context using this function; 
only `Sendable` values can be transported across the boundary. This means the compiler 
effectively makes it impossible to use the models returned from a query incorrectly in 
a multi-context environment, thus guaranteeing the SwiftData concurrency contract at 
compile time.     

### Observable Queries

Often in the context of view models or views we'd like to passively observe a Query and be notified of changes. SwiftQuery provides property wrappers that automatically update when the underlying data changes. These wrappers use Swift's `@Observable` framework and notify observers whenever the persistent store changes, even if that happens as a result of something like iCloud sync.

Observable queries use the main context by default. If you are using them inside a macro like `@Observable`, you must add `@ObservationIgnored`. Listeners will still be notified, but not through the enclosing observable. 

#### Fetch types


`FetchFirst` fetches and tracks the first result matching a query, if any.

```swift
struct PersonDetailView: View {
    @FetchFirst(Person.include(#Predicate { $0.name == "Jack" }))
    private var jack: Person?
    
    var body: some View {
        if let jack {
            Text("Jack is \(jack.age) years old")
        } else {
            Text("Jack not found")
        }
    }
}
```

`FetchAll` fetches and tracks all results matching a query. 

```swift
extension Query where T == Person {
    static var adults: Query {
        Person.include(#Predicate { $0.age >= 18 }).sortBy(\.name)
    }
}

@Observable
final class PeopleViewModel {
    @ObservationIgnored
    @FetchAll(.adults)
    var adults: [Person]
    
    var adultCount: Int {
        adults.count
    }
}
```

`FetchResults` fetches and tracks results as a lazy `FetchResultsCollection` with configurable batch size. Useful for very large datasets or performance critical screens.

```swift
@Reducer
struct PeopleFeature {
    @ObservableState
    struct State {
        @ObservationStateIgnored
        @FetchResults(Person.sortBy(\.name), batchSize: 50)
        var people: FetchResultsCollection<Person>?
        
        var peopleCount: Int {
            people?.count ?? 0
        }
    }
    
    // ...
}
```

#### Dependency Injection

All fetch wrappers use [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies) to access the model container. In your app setup:

```swift
@main
struct MyApp: App {
    let container = ModelContainer(for: Person.self)
    
    init() {
        prepareDependencies {
            $0.modelContainer = container
        }
    }
    
    // ...
}
```

This is also what enables them to be used outside of the SwiftUI environment.


## Installation

You can add SwiftQuery to an Xcode project by adding it to your project as a package.

> https://github.com/impossibleflight/swift-query

If you want to use SwiftQuery in a [SwiftPM](https://swift.org/package-manager/) project, it's as
simple as adding it to your `Package.swift`:

``` swift
dependencies: [
  .package(url: "https://github.com/impossibleflight/swift-query", from: "1.0.0")
]
```

And then adding the product to any target that needs access to the library:

```swift
.product(name: "SwiftQuery", package: "swift-query"),
```

## Authors

John Clayton (@johnclayton)

## License

swift-query is licensed under the MIT license. See [LICENSE](LICENSE)

## Acknowledgements

Inspired by [QueryKit](https://github.com/QueryKit/QueryKit)
