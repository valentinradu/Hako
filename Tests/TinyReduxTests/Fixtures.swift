//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
import Foundation
import TinyRedux

enum IdentityAction: Action {
    case login
    case logout
    case setUser(User)
    case like
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

class ProfileViewModel: ObservableObject {
    @Published var userEmail: String?
    @Published var likes: Int?
}

class IdentityEnvironment {
    @Published var logoutCalled: Bool = false
    func logout() async {
        logoutCalled = true
    }
}

struct AppState {
    var identity: IdentityState
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

let identityReducer: Reducer<IdentityState, IdentityAction, IdentityEnvironment> = { state, action in
    switch action {
    case .login:
        return { _, dispatch in
            dispatch(IdentityAction.setUser(User.main))
        }
    case let .setUser(user):
        state = .member(user)
        return .none
    case .logout:
        state = .guest
        return { env, _ in
            await env.logout()
        }
    case .like:
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
