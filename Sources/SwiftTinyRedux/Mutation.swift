//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol MutationProtocol<S, E> where S: Equatable {
    associatedtype S: Equatable
    associatedtype E
    func reduce(state: inout S) -> SideEffect<S, E>
    var isNoop: Bool { get }
}

public struct Mutation<S, E>: MutationProtocol where S: Equatable {
    typealias Reduce = (inout S) -> any SideEffectProtocol<S, E>
    private let _reduce: Reduce?

    public init<M>(_ mutation: M) where M: MutationProtocol, M.S == S, M.E == E {
        if let sameTypeMutation = mutation as? Mutation {
            self = sameTypeMutation
            return
        }

        _reduce = { state in
            let sideEffect = mutation.reduce(state: &state)
            return sideEffect
        }
    }

    public init(_ reduce: @escaping (inout S) -> SideEffect<S, E>) {
        _reduce = reduce
    }

    public init(_ reduce: @escaping (inout S) -> SideEffectGroup<S, E>) {
        _reduce = reduce
    }

    public func reduce(state: inout S) -> SideEffect<S, E> {
        guard let reduce = _reduce else {
            fatalError("Trying to reduce using a noop mutation")
        }
        return SideEffect(reduce(&state))
    }

    fileprivate init() {
        _reduce = nil
    }

    public var isNoop: Bool {
        _reduce == nil
    }
}

public extension MutationProtocol {
    static var noop: Mutation<S, E> {
        Mutation()
    }
}
