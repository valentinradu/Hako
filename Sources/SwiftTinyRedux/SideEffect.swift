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

public struct NoopSideEffect: SideEffect {
    public func perform(environment _: Any) async -> some Mutation {
        assertionFailure()
        return NoopMutation()
    }
}

public extension SideEffect where Self == NoopSideEffect {
    static var noop: NoopSideEffect { NoopSideEffect() }
}

public extension SideEffect {
    var asAnySideEffect: AnySideEffect {
        AnySideEffect(self)
    }
}

public struct AnySideEffect: SideEffect {
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
                return AnyMutation(.noop)
            }

            if type(of: sideEffect) == NoopSideEffect.self {
                return AnyMutation(.noop)
            }

            let nextMutation = try await sideEffect.perform(environment: environment)
            return AnyMutation(nextMutation)
        }
    }

    public func perform(environment: Any) async throws -> some Mutation {
        try await _perform(environment)
    }
}

extension AnySideEffect: Hashable {
    public static func == (lhs: AnySideEffect, rhs: AnySideEffect) -> Bool {
        lhs._base == rhs._base
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}
