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

typealias IdentitySideEffect = SideEffect<AppState, AppEnvironment, IdentityEnvironment>
typealias AppSideEffect = SideEffect<AppState, AppEnvironment, AppEnvironment>

struct LoginAction: Action {
    func reduce(state _: inout IdentityState) -> IdentitySideEffect? {
        return { _, store in
            let store = store.partial(state: \.identity,
                                      environment: \.identity)
            store.dispatch(action: SetUserAction(user: .main))
        }
    }
}

struct LogoutAction: Action {
    func reduce(state: inout IdentityState) -> IdentitySideEffect? {
        state = .guest
        return { env, _ in
            await env.logout()
        }
    }
}

struct SetUserAction: Action {
    let user: User
    func reduce(state: inout IdentityState) -> IdentitySideEffect? {
        state = .member(user)
        return .none
    }
}

struct LikeAction: Action {
    func reduce(state: inout IdentityState) -> IdentitySideEffect? {
        switch state {
        case .guest:
            break
        case var .member(user):
            user.likes += 1
            state = .member(user)
        }
        return .none
    }
}

struct ShowAlert: Action {
    let error: Error
    func reduce(state: inout AppState) -> AppSideEffect? {
        state.errors.append(error)
        return .none
    }
}

enum IdentityState: Hashable {
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

struct User: Hashable {
    static let main = User(name: "John",
                           email: "john@localhost.com",
                           likes: 0)
    let name: String
    let email: String
    var likes: Int
}

class IdentityEnvironment {
    @Published var logoutCalled: Bool = false
    func logout() async {
        logoutCalled = true
    }
}

struct AppState {
    var identity: IdentityState
    var errors: [Error]
}

struct AppEnvironment {
    let identity: IdentityEnvironment
}

extension Publisher {
    func timeout(_ value: TimeInterval) -> Publishers.Timeout<Self, RunLoop> {
        timeout(RunLoop.SchedulerTimeType.Stride(value),
                scheduler: RunLoop.main)
    }
}
