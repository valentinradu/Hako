//
//  File.swift
//
//
//  Created by Valentin Radu on 21/06/2022.
//

import Foundation

public protocol ActionProtocol: Hashable {
    associatedtype S: Hashable
    associatedtype E
    func perform(state: S) -> SideEffect<S, E>
}

public struct Action<S, E>: ActionProtocol where S: Hashable {
    private let _perform: (S) -> SideEffect<S, E>
    private let _base: AnyHashable

    public init<A>(_ action: A) where A: ActionProtocol, A.S == S, A.E == E {
        if let anyAction = action as? Action {
            self = anyAction
            return
        }

        _base = action
        _perform = action.perform
    }

    public init(_ perform: @escaping (S) -> SideEffect<S, E>, id: String = #function, salt: Int = #line) {
        _base = id + String(salt)
        _perform = perform
    }

    public var base: Any {
        _base.base
    }

    public func perform(state: S) -> SideEffect<S, E> {
        _perform(state)
    }
}

extension Action: Hashable {
    public static func == (lhs: Action, rhs: Action) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <A>(lhs: Action, rhs: A) -> Bool where A: ActionProtocol {
        lhs._base == AnyHashable(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}
