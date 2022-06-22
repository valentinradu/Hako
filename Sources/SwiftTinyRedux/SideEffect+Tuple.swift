//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public struct _TupleSideEffect: SideEffect {
    var children: [AnySideEffect]
    var strategy: SideEffectGroupStrategy = .serial

    init(children: [AnySideEffect],
         strategy: SideEffectGroupStrategy)
    {
        self.children = children
        self.strategy = strategy
    }

    init<A0>(_ value: A0?)
        where A0: SideEffect
    {
        if let value = value {
            children = [AnySideEffect(value)]
        }
        else {
            children = []
        }
    }

    init<A0>(_ value: A0)
        where A0: SideEffect
    {
        children = [AnySideEffect(value)]
    }

    init<A0, A1>(_ tuple: (A0, A1))
        where A0: SideEffect, A1: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
        ]
    }

    init<A0, A1, A2>(_ tuple: (A0, A1, A2))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
        ]
    }

    init<A0, A1, A2, A3>(_ tuple: (A0, A1, A2, A3))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect, A3: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
            AnySideEffect(tuple.3),
        ]
    }

    init<A0, A1, A2, A3, A4>(_ tuple: (A0, A1, A2, A3, A4))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect, A3: SideEffect, A4: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
            AnySideEffect(tuple.3),
            AnySideEffect(tuple.4),
        ]
    }

    init<A0, A1, A2, A3, A4, A5>(_ tuple: (A0, A1, A2, A3, A4, A5))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect, A3: SideEffect,
        A4: SideEffect, A5: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
            AnySideEffect(tuple.3),
            AnySideEffect(tuple.4),
            AnySideEffect(tuple.5),
        ]
    }

    init<A0, A1, A2, A3, A4, A5, A6>(_ tuple: (A0, A1, A2, A3, A4, A5, A6))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect, A3: SideEffect,
        A4: SideEffect, A5: SideEffect, A6: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
            AnySideEffect(tuple.3),
            AnySideEffect(tuple.4),
            AnySideEffect(tuple.5),
            AnySideEffect(tuple.6),
        ]
    }

    init<A0, A1, A2, A3, A4, A5, A6, A7>(_ tuple: (A0, A1, A2, A3, A4, A5, A6, A7))
        where A0: SideEffect, A1: SideEffect, A2: SideEffect, A3: SideEffect,
        A4: SideEffect, A5: SideEffect, A6: SideEffect, A7: SideEffect
    {
        children = [
            AnySideEffect(tuple.0),
            AnySideEffect(tuple.1),
            AnySideEffect(tuple.2),
            AnySideEffect(tuple.3),
            AnySideEffect(tuple.4),
            AnySideEffect(tuple.5),
            AnySideEffect(tuple.6),
            AnySideEffect(tuple.7),
        ]
    }

    public func strategy(_ strategy: SideEffectGroupStrategy) -> _TupleSideEffect {
        _TupleSideEffect(children: children,
                         strategy: strategy)
    }

    public func perform(env _: Any) async throws -> some Mutation {
        assertionFailure()
        return AnyMutation(.noop)
    }
}
