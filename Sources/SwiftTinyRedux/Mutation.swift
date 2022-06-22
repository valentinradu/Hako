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

public struct InlineMutation<S>: Mutation where S: Hashable {
    private let _perform: (inout S) -> AnySideEffect
    private let _uuid: UUID

    public init<SE>(perform: @escaping (S) -> SE) where SE: SideEffect {
        _perform = { AnySideEffect(perform($0)) }
        _uuid = UUID()
    }

    public func reduce(state: inout S) -> some SideEffect {
        _perform(&state)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_uuid)
    }

    public static func == (_: InlineMutation<S>, _: InlineMutation<S>) -> Bool {
        false
    }
}

public extension Mutation where Self == EmptyMutation {
    static var noop: EmptyMutation { EmptyMutation() }
}

public extension Mutation {
    var asAnyMutation: AnyMutation {
        AnyMutation(self)
    }
}

public struct AnyMutation: Mutation {
    private let _reduce: (inout AnyHashable) -> AnySideEffect
    private let _base: AnyHashable

    public init<M>(_ mut: M) where M: Mutation {
        if let anyMutation = mut as? AnyMutation {
            _base = anyMutation._base
            _reduce = anyMutation._reduce
            return
        }

        _base = mut
        _reduce = { state in
            guard var oldState = state.base as? M.S else {
                return AnySideEffect(.noop)
            }

            if type(of: mut) == EmptyMutation.self {
                return AnySideEffect(.noop)
            }

            let sideEffect = mut.reduce(state: &oldState)
            state = AnyHashable(oldState)

            return AnySideEffect(sideEffect)
        }
    }

    public var base: Any {
        _base.base
    }

    public func reduce(state: inout AnyHashable) -> some SideEffect {
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
