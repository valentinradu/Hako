//
//  SwiftTinyRedux.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation

public protocol SideEffect: Hashable {
    associatedtype E
    associatedtype M: Mutation

    func perform(environment: E) async throws -> M
}

public struct EmptySideEffect: SideEffect {
    public func perform(environment _: Any) async -> some Mutation {
        assertionFailure()
        return EmptyMutation()
    }
}

public extension SideEffect where Self == EmptySideEffect {
    static var empty: EmptySideEffect { EmptySideEffect() }
}

struct AnySideEffect: SideEffect {
    private let _perform: (Any) async throws -> AnyMutation
    private let _base: AnyHashable

    public var base: Any {
        _base.base
    }

    public init<SE>(_ sideEffect: SE) where SE: SideEffect {
        if let anySideEffect = sideEffect as? AnySideEffect {
            _base = anySideEffect._base
            _perform = anySideEffect._perform
            return
        }

        _base = sideEffect
        _perform = { environment in
            guard let environment = environment as? SE.E else {
                return AnyMutation(.empty)
            }

            if type(of: sideEffect) == EmptySideEffect.self {
                return AnyMutation(.empty)
            }

            let nextMutation = try await sideEffect.perform(environment: environment)
            return AnyMutation(nextMutation)
        }
    }

    func perform(environment: Any) async throws -> some Mutation {
        try await _perform(environment)
    }
}

extension AnySideEffect: Hashable {
    static func == (lhs: AnySideEffect, rhs: AnySideEffect) -> Bool {
        lhs._base == rhs._base
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}
