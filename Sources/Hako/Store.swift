//
//  File.swift
//
//
//  Created by Valentin Radu on 20/06/2022.
//

import Combine
import Foundation

@MainActor
public class Store<S>: ObservableObject where S: Equatable {
    @Published private var _state: S
    private var _tasks: [UUID: Task<Void, Never>]
    private var _cancellables: Set<AnyCancellable>

    public init(state: S) {
        _tasks = [:]
        _state = state
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

public extension Store {
    func perform(command: SideEffectCommand) async throws -> [any Mutation] {
        switch command {
        case .noop:
            break
        case let .perform(sideEffect):
            let mutation = try await perform(sideEffect: sideEffect)
            return [mutation]
        case let .merge(strategy, whenDone, commands):
            switch strategy {
            case .serial:
                var mutations: [any Mutation] = []
                for command in commands {
                    let others = try await perform(command: command)
                    mutations.append(contentsOf: others)
                }
                mutations.append(whenDone)
                return mutations
            case let .concurrent(priority):
                var mutations = try await withThrowingTaskGroup(of: [any Mutation]?.self,
                                                                returning: [any Mutation].self) { [weak self] group in
                    for command in commands {
                        group.addTask(priority: priority.taskPriority) { [weak self] in
                            try await self?.perform(command: command)
                        }
                    }

                    var mutations: [any Mutation] = []
                    while let result = await group.nextResult() {
                        switch result {
                        case .failure(error):
                            break
                        case let .success(other):
                            if let other {
                                mutations.append(contentsOf: other)
                            }
                        }
                    }

                    return mutations
                }

                mutations.append(whenDone)
                return mutations
            }
        }
    }

//    func dispatch(_ command: MutationCommand) {
//        switch command {
//        case .noop:
//            break
//        case let .perform(mutation):
//            reduce(mutation)
//        case .merge(strategy, commands):
//            for command in commands {
//                reduce(comm)
//            }
//        }
//    }
}

// MARK: Ingesting commands

public extension Store {
    func ingest(_ publisher: any Publisher<SideEffectCommand, Never>) {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        publisher.sink { [weak self] in
            self?.dispatch($0)
        }
        .store(in: &_cancellables)
    }
}

// MARK: Dispatching actions

private extension Store {
    func reduce(mutation: any Mutation) -> any SideEffect {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")
    }
}

// MARK: Performing side effects

private extension Store {
    nonisolated func perform(sideEffect: any SideEffect) async throws -> any Mutation {}
}

// MARK: Other utils

private extension Store {
    func removeTask(uuid: UUID) {
        _tasks.removeValue(forKey: uuid)
    }

    func withManagedTask(_ run: @escaping () async -> Void) {
        let uuid = UUID()
        let task = Task.detached { [weak self] in
            await run()
            await self?.removeTask(uuid: uuid)
        }
        _tasks[uuid] = task
    }
}
