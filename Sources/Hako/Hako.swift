//
//  File.swift
//
//
//  Created by Valentin Radu on 13/11/2022.
//

import Foundation

/// Mutations are operations that trigger a state update in the store.
/// They are resolved to pure functions that receive the state, apply
/// a transformation on it then return any side effects that might need
/// to be performed further.
///
/// Mutations drive the functional core of the store and are always
/// performed serially on the main thread.
public protocol Mutation: Hashable, Sendable {}

/// Side effects are operations that happen outside of the functional core
/// of the store and ultimately lead to a mutation.
/// Side effects are driving the imperative shell of the store. They're
/// resolved to async `Task<Mutation, Error>`s and can access and modify
/// the environment.
public protocol SideEffect: Hashable, Sendable {}

public enum ConcurrencyStrategy: Hashable, Sendable {
    public enum Priority: Hashable, Sendable {
        case medium
        case high
        case low
    }

    /// Execute each side effect one after the other
    case serial
    /// Execute side effects concurrently. Optionally set priority
    case concurrent(priority: Priority = .medium)
}

extension ConcurrencyStrategy.Priority {
    var taskPriority: TaskPriority {
        switch self {
        case .high:
            return .high
        case .low:
            return .low
        case .medium:
            return .medium
        }
    }
}

/// Commands control how mutations and side effects are performed
public indirect enum Command: Hashable, Sendable {
    case noop
    case performSideEffect(any SideEffect)
    case performMutation(any Mutation)
    case merge(strategy: ConcurrencyStrategy = .serial,
               commands: [Command])

    public static func == (lhs: Command, rhs: Command) -> Bool {
        switch (lhs, rhs) {
        case (.noop, .noop):
            return true
        case let (.performMutation(lhsMutation), .performMutation(rhsMutation)):
            return AnyHashable(lhsMutation) == AnyHashable(rhsMutation)
        case let (.performSideEffect(lhsSideEffect), .performSideEffect(rhsSideEffect)):
            return AnyHashable(lhsSideEffect) == AnyHashable(rhsSideEffect)
        case let (.merge(lhsStrategy, lhsCommands), .merge(rhsStrategy, rhsCommands)):
            return AnyHashable(lhsCommands) == AnyHashable(rhsCommands)
                && AnyHashable(lhsStrategy) == AnyHashable(rhsStrategy)
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .noop:
            hasher.combine(0)
        case let .performMutation(mutation):
            hasher.combine(1)
            hasher.combine(AnyHashable(mutation))
        case let .performSideEffect(sideEffect):
            hasher.combine(2)
            hasher.combine(AnyHashable(sideEffect))
        case let .merge(strategy, commands):
            hasher.combine(3)
            hasher.combine(commands)
            hasher.combine(strategy)
        }
    }
}
