//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation
import SwiftTinyRedux

enum IdentityError: Error {
    case unauthenticated
}

extension MutationProtocol where Self == Mutation<IdentityState, IdentityEnvironment> {
    static func setUser(_ user: User) -> Mutation<S, E> {
        Mutation { state in
            state.account = .member(user)
            return .noop
        }
    }

    static var login: Mutation<S, E> {
        Mutation { _ in
            SideEffect { _ in
                Mutation { state in
                    state.account = .member(.main)
                    return .noop
                }
            }
        }
    }

    static var parallelLogin: Mutation<S, E> {
        Mutation { _ in
            SideEffectGroup(strategy: .concurrent, sideEffects: [
                SideEffect<S, E> { _ in
                    Mutation { state in
                        state.account = .member(.main)
                        return .noop
                    }
                }
            ])
        }
    }

    static var logout: Mutation<S, E> {
        Mutation { state in
            state.account = .guest
            return .noop
        }
    }

    static func showAlert(error: IdentityError) -> Mutation<S, E> {
        Mutation { state in
            state.errors.append(error)
            return .noop
        }
    }

    static var like: Mutation<S, E> {
        Mutation { state in
            switch state.account {
            case .guest:
                break
            case var .member(user):
                user.likes += 1
                state.account = .member(user)
            }
            return .noop
        }
    }
}

enum Account: Equatable {
    case guest
    case member(User)

    var member: User? {
        switch self {
        case .guest:
            return nil
        case let .member(user):
            return user
        }
    }
}

struct IdentityState: Equatable {
    var account: Account
    var errors: [IdentityError]
}

extension IdentityState {
    init() {
        account = .guest
        errors = []
    }
}

struct User: Equatable {
    static let main = User(name: "John",
                           email: "john@localhost.com",
                           likes: 0)
    let name: String
    let email: String
    var likes: Int
}

actor IdentityEnvironment {
    @Published var logoutCalled: Bool = false
    func logout() async {
        logoutCalled = true
    }
}

extension Publisher {
    func timeout(_ value: TimeInterval) -> Publishers.Timeout<Self, RunLoop> {
        timeout(RunLoop.SchedulerTimeType.Stride(value),
                scheduler: RunLoop.main)
    }
}

extension Store {
    convenience init(state: IdentityState = .init()) where S == IdentityState, E == IdentityEnvironment {
        self.init(state: state,
                  env: .init())
    }
}
