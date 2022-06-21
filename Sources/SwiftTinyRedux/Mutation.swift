//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol Mutation: Hashable {
    associatedtype S: Hashable
    associatedtype SE: SideEffect
    @SideEffectBuilder func reduce(state: inout S) -> SE
}

public struct NoopMutation: Mutation {
    public func reduce(state _: inout AnyHashable) -> some SideEffect {
        assertionFailure()
        return NoopSideEffect()
    }
}

public extension Mutation where Self == NoopMutation {
    static var noop: NoopMutation { NoopMutation() }
}

struct AnyMutation: Mutation {
    private let _reduce: (inout AnyHashable) -> AnySideEffect
    private let _base: AnyHashable

    init(_ mutation: AnyMutation) {
        self = mutation
    }

    init<M>(_ mutation: M) where M: Mutation {
        if let anyMutation = mutation as? AnyMutation {
            _base = anyMutation._base
            _reduce = anyMutation._reduce
            return
        }

        _base = mutation
        _reduce = { state in
            guard var oldState = state.base as? M.S else {
                return AnySideEffect(.noop)
            }

            if type(of: mutation) == NoopMutation.self {
                return AnySideEffect(.noop)
            }

            let sideEffect = mutation.reduce(state: &oldState)
            state = AnyHashable(oldState)

            return AnySideEffect(sideEffect)
        }
    }

    var base: Any {
        _base.base
    }

    func reduce(state: inout AnyHashable) -> some SideEffect {
        _reduce(&state)
    }
}

extension AnyMutation: Hashable {
    public static func == (lhs: AnyMutation, rhs: AnyMutation) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <M>(lhs: AnyMutation, rhs: M) -> Bool where M: Mutation {
        lhs._base == AnyHashable(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}
