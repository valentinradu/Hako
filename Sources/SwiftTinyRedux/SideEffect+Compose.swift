//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

public enum SideEffectGroupStrategy {
    case serial
    case concurrent
}

public struct SideEffectGroup<E>: SideEffect {
    private let _sideEffects: AnySideEffect

    public init<SE>(strategy: SideEffectGroupStrategy = .serial,
             @SideEffectBuilder builder: () -> SE) where SE: SideEffect, SE.E == E
    {
        let result = builder()

        if let tuple = result as? _TupleSideEffect {
            _sideEffects = AnySideEffect(tuple.strategy(strategy))
        }
        else {
            _sideEffects = AnySideEffect(result)
        }
    }

    public func perform(environment: E) async throws -> some Mutation {
        try await _sideEffects.perform(environment: environment)
    }
}
