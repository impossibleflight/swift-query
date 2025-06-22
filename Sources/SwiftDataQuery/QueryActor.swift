//  QueryActor.swift
//  swift-query
//
//  Created by John Clayton on 2025/6/21.
//  Copyright © 2025 Impossible Flight, LLC. All rights reserved.
//
import Foundation
import SwiftData

@ModelActor
public actor QueryActor: Sendable {
    public func perform<T>(
        _ block: () throws -> T
    ) rethrows -> T {
        try block()
    }
}

public extension ModelContainer {
    func perform<T>(
        _ block: () async throws -> T
    ) async rethrows -> T {
        try await block()
    }
}
