//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Combine
import Foundation

@MainActor
public class Store<S>: ObservableObject where S: Hashable {
    public typealias StateReducer = (inout S, any Mutation) -> any SideEffect
    public typealias SideEffectResolver = (any SideEffect) async throws -> any Mutation
    public typealias ErrorTransformer = (any SideEffect, any Error) -> any Mutation
    @Published private var _state: S
    private var _tasks: [AnyHashable: Task<Void, Never>]
    private var _cancellables: Set<AnyCancellable>
    private var _stateReducer: StateReducer
    private var _sideEffectResolver: SideEffectResolver
    private var _errorTransformer: ErrorTransformer

    public init(initialState: S,
                stateReducer: @escaping StateReducer,
                sideEffectResolver: @escaping SideEffectResolver,
                errorTransformer: @escaping ErrorTransformer) {
        _tasks = [:]
        _state = initialState
        _stateReducer = stateReducer
        _sideEffectResolver = sideEffectResolver
        _errorTransformer = errorTransformer
        _cancellables = []
    }

    deinit {
        for (_, task) in _tasks {
            task.cancel()
        }
    }
}

public extension Store {
    var state: S {
        _state
    }
}

// MARK: Dispatching mutations and side effects

public extension Store {
    func dispatch(_ mutation: any Mutation) {
        let command = perform(mutation: mutation)
        _dispatch(command)
    }

    func dispatch(_ sideEffect: any SideEffect) {
        _dispatch(.performSideEffect(sideEffect))
    }

    private func _dispatch(_ command: Command) {
        let task = Task.detached { [weak self] in
            do {
                var command = command
                while let nextCommand = try await self?.perform(command: command), nextCommand != .noop, command != .noop {
                    command = try await self?.perform(command: nextCommand) ?? .noop
                }
                await self?.removeTask(forKey: command)
            } catch {
                await self?.removeTask(forKey: command)
                fatalError()
            }
        }
        _tasks[command] = task
    }
}

// MARK: Ingesting commands

public extension Store {
    func ingest(_ publisher: any Publisher<any SideEffect, Never>) {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        publisher.sink { [weak self] in
            self?.dispatch($0)
        }
        .store(in: &_cancellables)
    }

    func ingest(_ publisher: any Publisher<any Mutation, Never>) {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        publisher.sink { [weak self] in
            self?.dispatch($0)
        }
        .store(in: &_cancellables)
    }
}

// MARK: Performing mutations, side effects and commands

private extension Store {
    func perform(command: Command) async throws -> Command {
        switch command {
        case .noop:
            return .noop
        case let .performSideEffect(sideEffect):
            let mutationCommand = try await perform(sideEffect: sideEffect)
            return mutationCommand
        case let .performMutation(mutation):
            let sideEffectCommand = perform(mutation: mutation)
            return sideEffectCommand
        case let .merge(strategy, commands):
            guard !commands.isEmpty else {
                return .noop
            }

            switch strategy {
            case .serial:
                var mutationCommands: [Command] = []
                for command in commands where command != .noop {
                    let others = try await perform(command: command)
                    mutationCommands.append(others)
                }
                return .merge(strategy: strategy, commands: mutationCommands)
            case let .concurrent(priority):
                let mutationCommands = await withThrowingTaskGroup(of: Command?.self,
                                                                   returning: Command.self) { [weak self] group in
                    for command in commands where command != .noop {
                        group.addTask(priority: priority.taskPriority) { [weak self] in
                            try await self?.perform(command: command)
                        }
                    }

                    var mutationCommands: [Command] = []
                    while let result = await group.nextResult() {
                        switch result {
                        case let .failure(error):
                            fatalError(error.localizedDescription)
                        case let .success(other):
                            if let other {
                                mutationCommands.append(other)
                            }
                        }
                    }

                    return .merge(strategy: strategy, commands: mutationCommands)
                }

                return .merge(strategy: strategy, commands: [mutationCommands])
            }
        }
    }

    func perform(mutation: any Mutation) -> Command {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")
        return .performSideEffect(_stateReducer(&_state, mutation))
    }

    func perform(sideEffect: any SideEffect) async throws -> Command {
        try await .performMutation(_sideEffectResolver(sideEffect))
    }
}

// MARK: Other utils

private extension Store {
    func removeTask(forKey key: any Hashable) {
        _tasks.removeValue(forKey: AnyHashable(key))
    }
}
