//
//  File.swift
//
//
//  Created by Valentin Radu on 21/06/2022.
//

import Foundation

public protocol Action: Hashable {
    associatedtype SE: SideEffect
    @SideEffectBuilder func perform() -> SE
}

struct AnyAction: Action {
    private let _perform: () -> AnySideEffect
    private let _base: AnyHashable

    init<A>(_ action: A) where A: Action {
        if let anyAction = action as? AnyAction {
            _base = anyAction._base
            _perform = anyAction._perform
            return
        }

        _base = action
        _perform = {
            AnySideEffect(action.perform())
        }
    }

    var base: Any {
        _base.base
    }

    func perform() -> some SideEffect {
        _perform()
    }
}

extension AnyAction {
    public static func == (lhs: AnyAction, rhs: AnyAction) -> Bool {
        lhs._base == rhs._base
    }

    public static func == <M>(lhs: AnyAction, rhs: M) -> Bool where M: Mutation {
        lhs._base == AnyHashable(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }
}
