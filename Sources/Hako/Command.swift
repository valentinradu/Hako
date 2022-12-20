//
//  File.swift
//
//
//  Created by Valentin Radu on 17/12/2022.
//

import Foundation

public indirect enum Command<Mutation, SideEffect> {
    case noop
    case sideEffect(SideEffect)
    case mutation(Mutation)
    case serial([Self])
    case concurrent([Self])
}

extension Command: Equatable where Mutation: Equatable, SideEffect: Equatable {}
extension Command: Hashable where SideEffect: Hashable, Mutation: Hashable {}
extension Command: Sendable where SideEffect: Sendable, Mutation: Sendable {}
