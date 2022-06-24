//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public protocol MutationProtocol: Hashable {
    associatedtype S: Hashable
    associatedtype E
    func reduce(state: inout S) -> SideEffect<S, E>
    var isNoop: Bool { get }
}

public extension MutationProtocol {
    var isNoop: Bool { false }
}

public struct Mutation<S, E>: MutationProtocol where S: Hashable {
    private let _reduce: (inout S) -> SideEffect<S, E>
    private let _base: AnyHashable
    public let isNoop: Bool

    public init<M>(_ wrapped: () -> M) where M: MutationProtocol, M.S == S, M.E == E {
        let mut = wrapped()
        if let anyMutation = mut as? Mutation {
            self = anyMutation
            return
        }

        _base = mut
        _reduce = { state in
            let sideEffect = mut.reduce(state: &state)
            return sideEffect
        }
        isNoop = false
    }

    public init(_ reduce: @escaping (inout S) -> SideEffect<S, E>) {
        _base = UUID()
        _reduce = reduce
        isNoop = false
    }
    
    private init() {
        _base = 0
        _reduce = { _ in fatalError() }
        isNoop = true
    }
    
    public var base: Any {
        _base.base
    }

    public func reduce(state: inout S) -> SideEffect<S, E> {
        _reduce(&state)
    }
}

extension Mutation: Hashable {
    public static func == (lhs: Mutation, rhs: Mutation) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <M>(lhs: Mutation, rhs: M) -> Bool where M: MutationProtocol {
        lhs._base == AnyHashable(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}

public extension Mutation {
    static var noop: Mutation<S, E> {
        Mutation()
    }
}
