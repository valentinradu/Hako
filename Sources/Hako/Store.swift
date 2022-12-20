//
//  File.swift
//
//
//  Created by Valentin Radu on 17/12/2022.
//

import Foundation

@MainActor
public class Store<State, SideEffect, Mutation>: ObservableObject
    where State: Hashable & Sendable,
    SideEffect: Hashable & Sendable,
    Mutation: Hashable & Sendable {
    private let _service: any Service<SideEffect, Mutation>
    private let _reducer: any Reducer<SideEffect, Mutation, State>

    public init(service: any Service<SideEffect, Mutation>,
                reducer: any Reducer<SideEffect, Mutation, State>) {
        _service = service
        _reducer = reducer
    }

    public func dispatch(_ mutation: Mutation) {}

    public func dispatch(_ sideEffect: SideEffect) async throws {}

    public var state: State {
        _reducer.state
    }
}

@MainActor
public struct CompositeStore<State, State1, SideEffect1, Mutation1, State2, SideEffect2, Mutation2>
    where State: Hashable & Sendable, State1: Hashable & Sendable, State2: Hashable & Sendable,
    SideEffect1: Hashable & Sendable, SideEffect2: Hashable & Sendable,
    Mutation1: Hashable & Sendable, Mutation2: Hashable & Sendable {
    public typealias MetaReducer = (State1, State2) -> State

    private let _store: Store<State1, SideEffect1, Mutation1>
    private let _other: Store<State2, SideEffect2, Mutation2>
    private let _metaReducer: MetaReducer

    public init(store: Store<State1, SideEffect1, Mutation1>,
                other: Store<State2, SideEffect2, Mutation2>,
                metaReducer: @escaping MetaReducer) {
        _store = store
        _other = other
        _metaReducer = metaReducer
    }

    public func dispatch(_ mutation: Mutation1) {
        _store.dispatch(mutation)
    }

    public func dispatch(_ sideEffect: SideEffect1) async throws {
        try await _store.dispatch(sideEffect)
    }

    public func dispatch(_ mutation: Mutation2) {
        _other.dispatch(mutation)
    }

    public func dispatch(_ sideEffect: SideEffect2) async throws {
        try await _other.dispatch(sideEffect)
    }

    public var state: State {
        _metaReducer(_store.state, _other.state)
    }
}


//// MARK: Dispatching mutations and side effects
//
//public extension Store {
//    func dispatch(_ mutation: any Mutation) {
//        let command = perform(mutation: mutation)
//        _dispatch(command)
//    }
//
//    func dispatch(_ sideEffect: any SideEffect) {
//        _dispatch(.performSideEffect(sideEffect))
//    }
//
//    private func _dispatch(_ command: Command) {
//        let task = Task.detached { [weak self] in
//            do {
//                var command = command
//                while let nextCommand = try await self?.perform(command: command), nextCommand != .noop, command != .noop {
//                    command = try await self?.perform(command: nextCommand) ?? .noop
//                }
//                await self?.removeTask(forKey: command)
//            } catch {
//                await self?.removeTask(forKey: command)
//                fatalError()
//            }
//        }
//        _tasks[command] = task
//    }
//}
//
//// MARK: Ingesting commands
//
//public extension Store {
//    func ingest(_ publisher: any Publisher<any SideEffect, Never>) {
//        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")
//
//        publisher.sink { [weak self] in
//            self?.dispatch($0)
//        }
//        .store(in: &_cancellables)
//    }
//
//    func ingest(_ publisher: any Publisher<any Mutation, Never>) {
//        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")
//
//        publisher.sink { [weak self] in
//            self?.dispatch($0)
//        }
//        .store(in: &_cancellables)
//    }
//}
//
//// MARK: Performing mutations, side effects and commands
//
//private extension Store {
//    func perform(command: Command) async throws -> Command {
//        switch command {
//        case .noop:
//            return .noop
//        case let .performSideEffect(sideEffect):
//            let mutationCommand = try await perform(sideEffect: sideEffect)
//            return mutationCommand
//        case let .performMutation(mutation):
//            let sideEffectCommand = perform(mutation: mutation)
//            return sideEffectCommand
//        case let .merge(strategy, commands):
//            guard !commands.isEmpty else {
//                return .noop
//            }
//
//            switch strategy {
//            case .serial:
//                var mutationCommands: [Command] = []
//                for command in commands where command != .noop {
//                    let others = try await perform(command: command)
//                    mutationCommands.append(others)
//                }
//                return .merge(strategy: strategy, commands: mutationCommands)
//            case let .concurrent(priority):
//                let mutationCommands = await withThrowingTaskGroup(of: Command?.self,
//                                                                   returning: Command.self) { [weak self] group in
//                    for command in commands where command != .noop {
//                        group.addTask(priority: priority.taskPriority) { [weak self] in
//                            try await self?.perform(command: command)
//                        }
//                    }
//
//                    var mutationCommands: [Command] = []
//                    while let result = await group.nextResult() {
//                        switch result {
//                        case let .failure(error):
//                            fatalError(error.localizedDescription)
//                        case let .success(other):
//                            if let other {
//                                mutationCommands.append(other)
//                            }
//                        }
//                    }
//
//                    return .merge(strategy: strategy, commands: mutationCommands)
//                }
//
//                return .merge(strategy: strategy, commands: [mutationCommands])
//            }
//        }
//    }
//
//    func perform(mutation: any Mutation) -> Command {
//        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")
//        return .performSideEffect(_stateReducer(&_state, mutation))
//    }
//
//    func perform(sideEffect: any SideEffect) async throws -> Command {
//        try await .performMutation(_sideEffectResolver(sideEffect))
//    }
//}
//
//// MARK: Other utils
//
//private extension Store {
//    func removeTask(forKey key: any Hashable) {
//        _tasks.removeValue(forKey: AnyHashable(key))
//    }
//}
