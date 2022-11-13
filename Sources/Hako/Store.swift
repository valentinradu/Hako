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

// MARK: Ingesting commands

public extension Store {
    func ingest(_ publisher: any Publisher<Command<S>, Never>) {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        publisher.sink { [weak self] in
            guard let self = self else { return }
            self.dispatch($0)
        }
        .store(in: &_cancellables)
    }
}

public extension Store {
    func dispatch(_ command: Command<S>) {
        switch command {
        case .noop:
            break
        case let .perform(sideEffect):
            withManagedTask { [weak self] in
                guard let self = self else { return }
                await self.perform(sideEffect)
            }
        case let .performMany(strategy, sideEffects):
            withManagedTask { [weak self] in
                guard let self = self else { return }
                await self.perform(strategy: strategy, sideEffects: sideEffects)
            }
        case let .reduce(mutation):
            reduce(mutation)
        case let .reduceMany(mutations):
            reduce(mutations)
        }
    }
}

// MARK: Dispatching actions

private extension Store {
    func reduce(_ mutation: any Mutation<S>) {
        precondition(Thread.isMainThread, "\(#function) should always be called on the main thread")

        let command = mutation.reduce(state: &_state)
        dispatch(command)
    }

    func reduce(_ mutations: [any Mutation<S>]) {
        for mutation in mutations {
            reduce(mutation)
        }
    }
}

// MARK: Performing side effects

private extension Store {
    nonisolated func perform(_ sideEffect: any SideEffect<S>) async {
        let command = await sideEffect.perform()
        await dispatch(command)
    }

    nonisolated func perform(strategy: PerformManyStrategy, sideEffects: [any SideEffect<S>]) async {
        switch strategy {
        case .serial:
            for sideEffect in sideEffects {
                await perform(sideEffect)
            }
        case .concurrent:
            await withTaskGroup(of: Void.self) { [weak self] group in
                for sideEffect in sideEffects {
                    group.addTask { [weak self] in
                        guard let self = self else { return }
                        await self.perform(sideEffect)
                    }
                }

                await group.waitForAll()
            }
        }
    }
}

// MARK: Other utils

private extension Store {
    func removeTask(uuid: UUID) {
        _tasks.removeValue(forKey: uuid)
    }

    func withManagedTask(_ run: @escaping () async -> Void) {
        let uuid = UUID()
        let task = Task.detached { [weak self] in
            guard let self = self else { return }
            await run()
            await self.removeTask(uuid: uuid)
        }
        _tasks[uuid] = task
    }
}
