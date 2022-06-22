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

    func perform(env: E) async throws -> M
}

public struct EmptySideEffect: SideEffect {
    public func perform(env _: Any) async -> some Mutation {
        assertionFailure()
        return EmptyMutation()
    }
}

public struct InlineSideEffect<E>: SideEffect {
    private let _perform: (E) async throws -> AnyMutation
    private let _uuid: UUID

    public init<M>(perform: @escaping (E) async throws -> M) where M: Mutation {
        _perform = { try await AnyMutation(perform($0)) }
        _uuid = UUID()
    }

    public func perform(env: E) async throws -> some Mutation {
        try await _perform(env)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_uuid)
    }

    public static func == (_: InlineSideEffect<E>, _: InlineSideEffect<E>) -> Bool {
        false
    }
}

public extension SideEffect where Self == EmptySideEffect {
    static var noop: EmptySideEffect { EmptySideEffect() }
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
        _perform = { env in
            guard let env = env as? SE.E else {
                return AnyMutation(.noop)
            }

            if type(of: sideEffect) == EmptySideEffect.self {
                return AnyMutation(.noop)
            }

            let nextMutation = try await sideEffect.perform(env: env)
            return AnyMutation(nextMutation)
        }
    }

    public func perform(env: Any) async throws -> some Mutation {
        try await _perform(env)
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
