# Contributing

## Building and testing

```bash
swift build
swift test
swift test --filter QueryTests          # one suite
swift test --filter compoundInclude_results   # one test
```

Platforms: iOS 18, macOS 15, watchOS 11. Swift 6 language mode. CI runs `swift build` and `swift test` on GitHub's macOS runner for every push and pull request to `main`.

If the whole test run dies with signal 11 while single suites pass, suspect the Point-Free dependency pins before the code: `IssueReporting` mirrors Swift Testing's internals and has to be current for a new Xcode.

## Code style

- Prefer `private` for anything not part of the API.
- Group related functions in separate extensions rather than with `// MARK:` comments. A short file does not need extensions at all.
- Public symbols carry DocC comments with proper symbol links, ``Type/method(param:)``. Every operation on `Query` has a static twin on `PersistentModel`; document both and cross-link them.
- No `try!` in tests. In library code only where the expression provably cannot throw, and say why in a comment.
- Comments otherwise explain a non-obvious why that the code cannot show. Not the what.

## Testing

Swift Testing, one suite per source file, all sharing the `Person` model in `Tests/SwiftQueryTests/Model.swift`.

- Test names are lowerCamelCase with an underscore separating the scenario from the operation: `compoundInclude_results`, `findOrCreate_creates`.
- Use `#require` to unwrap, then use the value. Do not test for nil and optional-chain afterwards.
- Do not comment on what an expectation obviously asserts.
- `FetchTests` and `ConcurrentFetchTests` mirror each other: the same operations on the main actor and inside a model actor. The `PersistentModel*Tests` suites cover the static forms. A new operation goes in each suite that applies.
- `FetchWrapperTests` and `FetchProjectionTests` wait on a short sleep after each save for the wrapper to re-fetch. Run them a few times when touching the wrappers; a failure that appears only sometimes is a timing problem in the wrapper, not the test.
- Fetch wrapper tests wait on a short `Task.sleep` for the change notification to land before asserting.

## Pull requests

Work lands on `main` through a pull request with a green CI run. Say in the description whether the change is a fix, new API or a breaking change, since that decides the next version number.

Dependencies are pinned in `Package.resolved`, which is committed. Bump pins in their own commit with the reason.
