//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol MutationProtocol<S, E>: Equatable where S: Equatable {
    associatedtype S: Equatable
    associatedtype E
    func reduce(state: inout S) -> any SideEffectProtocol<S, E>
    var isNoop: Bool { get }
}

public extension MutationProtocol {
    var isNoop: Bool { false }
}

public struct Mutation<S, E>: MutationProtocol where S: Equatable {
    private let _reduce: (inout S) -> any SideEffectProtocol<S, E>
    private let _base: AnyEquatable
    public let isNoop: Bool

    public init<M>(_ mut: M) where M: MutationProtocol, M.S == S, M.E == E {
        if let anyMutation = mut as? Mutation {
            self = anyMutation
            return
        }

        _base = AnyEquatable(mut)
        _reduce = { state in
            let sideEffect = mut.reduce(state: &state)
            return sideEffect
        }
        isNoop = false
    }

    public init(_ reduce: @escaping (inout S) -> SideEffect<S, E>, id: String = #function, salt: Int = #line) {
        _base = AnyEquatable(id + String(salt))
        _reduce = reduce
        isNoop = false
    }

    public init(_ reduce: @escaping (inout S) -> SideEffectGroup<S, E>, id: String = #function, salt: Int = #line) {
        _base = AnyEquatable(id + String(salt))
        _reduce = reduce
        isNoop = false
    }

    fileprivate init() {
        _base = AnyEquatable(0)
        _reduce = { _ in fatalError() }
        isNoop = true
    }

    public var base: Any {
        _base.base
    }

    public func reduce(state: inout S) -> any SideEffectProtocol<S, E> {
        _reduce(&state)
    }
}

extension Mutation: Equatable {
    public static func == (lhs: Mutation, rhs: Mutation) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <M>(lhs: Mutation, rhs: M) -> Bool where M: MutationProtocol {
        AnyEquatable(lhs._base) == AnyEquatable(rhs)
    }
}

public extension MutationProtocol {
    static var noop: Mutation<S, E> {
        Mutation()
    }
}
