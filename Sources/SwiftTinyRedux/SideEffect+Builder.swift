//
//  File.swift
//  
//
//  Created by Valentin Radu on 20/06/2022.
//

import Foundation

@resultBuilder
public enum SideEffectBuilder {
    public static func buildBlock() -> EmptySideEffect {
        EmptySideEffect()
    }
    
    public static func buildBlock(_ value: Never) -> Never {}

    public static func buildBlock<A>(_ value: A) -> some SideEffect
        where A: SideEffect
    {
        return _TupleSideEffect(value)
    }

    public static func buildIf<A>(_ value: A?) -> some SideEffect
        where A: SideEffect
    {
        _TupleSideEffect(value)
    }

    public static func buildEither<A>(first: A) -> some SideEffect
        where A: SideEffect
    {
        _TupleSideEffect(first)
    }

    public static func buildEither<A>(second: A) -> some SideEffect
        where A: SideEffect
    {
        _TupleSideEffect(second)
    }

    public static func buildBlock<D0, D1>(_ d0: D0,
                                          _ d1: D1) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect
    {
        _TupleSideEffect((d0, d1))
    }

    public static func buildBlock<D0, D1, D2>(_ d0: D0,
                                              _ d1: D1,
                                              _ d2: D2) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect
    {
        _TupleSideEffect((d0, d1, d2))
    }

    public static func buildBlock<D0, D1, D2, D3>(_ d0: D0,
                                                  _ d1: D1,
                                                  _ d2: D2,
                                                  _ d3: D3) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect, D3: SideEffect
    {
        _TupleSideEffect((d0, d1, d2, d3))
    }

    public static func buildBlock<D0, D1, D2, D3, D4>(_ d0: D0,
                                                      _ d1: D1,
                                                      _ d2: D2,
                                                      _ d3: D3,
                                                      _ d4: D4) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect, D3: SideEffect, D4: SideEffect
    {
        _TupleSideEffect((d0, d1, d2, d3, d4))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5>(_ d0: D0,
                                                          _ d1: D1,
                                                          _ d2: D2,
                                                          _ d3: D3,
                                                          _ d4: D4,
                                                          _ d5: D5) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect, D3: SideEffect, D4: SideEffect, D5: SideEffect
    {
        _TupleSideEffect((d0, d1, d2, d3, d4, d5))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6>(_ d0: D0,
                                                              _ d1: D1,
                                                              _ d2: D2,
                                                              _ d3: D3,
                                                              _ d4: D4,
                                                              _ d5: D5,
                                                              _ d6: D6) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect, D3: SideEffect, D4: SideEffect, D5: SideEffect, D6: SideEffect
    {
        _TupleSideEffect((d0, d1, d2, d3, d4, d5, d6))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6, D7>(_ d0: D0,
                                                                  _ d1: D1,
                                                                  _ d2: D2,
                                                                  _ d3: D3,
                                                                  _ d4: D4,
                                                                  _ d5: D5,
                                                                  _ d6: D6,
                                                                  _ d7: D7) -> _TupleSideEffect
    where D0: SideEffect, D1: SideEffect, D2: SideEffect, D3: SideEffect, D4: SideEffect, D5: SideEffect, D6: SideEffect, D7: SideEffect
    {
        _TupleSideEffect((d0, d1, d2, d3, d4, d5, d6, d7))
    }
}
