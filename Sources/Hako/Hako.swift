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
public protocol Mutation: Hashable {}

/// Side effects are operations that happen outside of the functional core
/// of the store and ultimately lead to a mutation.
/// Side effects are driving the imperative shell of the store. They're
/// resolved to async `Task<Mutation, Error>`s and can access and modify
/// the environment.
public protocol SideEffect: Hashable {}

public enum ConcurrencyStrategy: Hashable {
    public enum Priority: Hashable {
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
public indirect enum SideEffectCommand: Hashable {
    case noop
    case perform(sideEffect: any SideEffect)
    case merge(strategy: Strategy = .serial,
               whenDone: MutationCommand = .noop,
               commands: [SideEffectCommand])

    public static func == (lhs: SideEffectCommand, rhs: SideEffectCommand) -> Bool {
        switch (lhs, rhs) {
        case (.noop, .noop):
            return true
        case let (.perform(lhsMutation), .perform(rhsMutation)):
            return AnyHashable(lhsMutation) == AnyHashable(rhsMutation)
        case let (.merge(lhsStrategy, lhsWhenDone, lhsCommands), .merge(rhsStrategy, rhsWhenDone, rhsCommands)):
            return AnyHashable(lhsCommands) == AnyHashable(rhsCommands)
                && AnyHashable(lhsStrategy) == AnyHashable(rhsStrategy)
                && AnyHashable(lhsWhenDone) == AnyHashable(rhsWhenDone)
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .noop:
            hasher.combine(0)
        case let .perform(mutation):
            hasher.combine(1)
            hasher.combine(AnyHashable(mutation))
        case let .merge(strategy, whenDone, commands):
            hasher.combine(2)
            hasher.combine(commands)
            hasher.combine(strategy)
            hasher.combine(whenDone)
        }
    }
}

public indirect enum MutationCommand: Hashable {
    case noop
    case perform(mutation: any Mutation)
    case merge(strategy: Strategy = .serial,
               commands: [MutationCommand])

    public static func == (lhs: MutationCommand, rhs: MutationCommand) -> Bool {
        switch (lhs, rhs) {
        case (.noop, .noop):
            return true
        case let (.perform(lhsMutation), .perform(rhsMutation)):
            return AnyHashable(lhsMutation) == AnyHashable(rhsMutation)
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
        case let .perform(mutation):
            hasher.combine(1)
            hasher.combine(AnyHashable(mutation))
        case let .merge(strategy, commands):
            hasher.combine(2)
            hasher.combine(commands)
            hasher.combine(strategy)
        }
    }
}
