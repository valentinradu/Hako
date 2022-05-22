//
//  File.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Foundation
import TinyRedux

enum IdentityAction {
    case login
    case logout
    case setUser(User)
}

enum IdentityState {
    case guest
    case member(User)
}

struct User {
    let name: String
    let email: String
}

struct IdentityEnvironment {
    func logout() async {}
}

struct AppState {
    let user: IdentityState
}

let identityReducer: Reducer<IdentityState, IdentityAction, IdentityEnvironment> = { state, action in
    switch action {
    case .login:
        return { _, dispatch in
            let user = User(name: "John",
                            email: "john@localhost.com")
            dispatch(IdentityAction.setUser(user))
        }
    case let .setUser(user):
        state = .member(user)
        return .none
    case .logout:
        state = .guest
        return { env, _ in
            await env.logout()
        }
    }
}
