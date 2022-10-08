//
//  File.swift
//
//
//  Created by Valentin Radu on 21/06/2022.
//

import Foundation

public protocol ActionProtocol: Equatable {
    associatedtype S: Equatable
    associatedtype E
    func perform(state: S) -> SideEffect<S, E>
}

public struct Action<S, E>: ActionProtocol where S: Equatable {
    private let _perform: (S) -> SideEffect<S, E>
    private let _base: AnyEquatable

    public init<A>(_ action: A) where A: ActionProtocol, A.S == S, A.E == E {
        if let anyAction = action as? Action {
            self = anyAction
            return
        }

        _base = AnyEquatable(action)
        _perform = action.perform
    }

    public init(_ perform: @escaping (S) -> SideEffect<S, E>, id: String = #function, salt: Int = #line) {
        _base = AnyEquatable(id + String(salt))
        _perform = perform
    }

    public var base: Any {
        _base.base
    }

    public func perform(state: S) -> SideEffect<S, E> {
        _perform(state)
    }
}

extension Action: Equatable {
    public static func == (lhs: Action, rhs: Action) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <A>(lhs: Action, rhs: A) -> Bool where A: ActionProtocol {
        AnyEquatable(lhs._base) == AnyEquatable(rhs)
    }
}
