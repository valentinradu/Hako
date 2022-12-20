//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Hako

enum AuthSideEffect {
    case login
    case logout
}

enum AuthMutation {
    case updateEmail
    case updatePassword
}

struct AuthState {}

struct AuthService: Service {
    func perform(_ sideEffect: AuthSideEffect) async throws -> Command<AuthMutation, AuthSideEffect> {
        switch sideEffect {
        case .logout:
            return .noop
        case .login:
            return .noop
        }
    }
}

func reduceAuth(state: inout AuthState, mutation: AuthMutation) -> Command<AuthMutation, AuthSideEffect> {
    switch mutation {
    case .updateEmail:
        return .noop
    case .updatePassword:
        return .noop
    }
}
