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

public struct EmptyMutation: Mutation {
    public func reduce(state _: inout AnyHashable) -> some SideEffect {
        assertionFailure()
        return EmptySideEffect()
    }
}

public extension Mutation where Self == EmptyMutation {
    static var empty: EmptyMutation { EmptyMutation() }
}

struct AnyMutation: Mutation {
    private let _reduce: (inout AnyHashable) -> AnySideEffect
    private let _base: AnyHashable

    init(_ mutation: AnyMutation) {
        self = mutation
    }

    init<M>(_ mutation: M) where M: Mutation {
        _base = mutation
        _reduce = { state in
            guard var oldState = state.base as? M.S else {
                return AnySideEffect(.empty)
            }

            if type(of: mutation) == EmptyMutation.self {
                return AnySideEffect(.empty)
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
