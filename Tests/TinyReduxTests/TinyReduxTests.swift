//
//  TinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

@testable @_spi(testable) import TinyRedux
import XCTest

final class TinyReduxTests: XCTestCase {
    private var _store: Store<AppState, AppEnvironment>!

    override func setUp() async throws {
        let state: AppState = .init(identity: .guest)
        let env: AppEnvironment = .init(identity: .init())
        _store = Store(initialState: state,
                       environment: env)
        await _store.add(reducer: identityReducer,
                         state: \.identity,
                         environment: \.identity)
    }

    func testSimpleDispatch() async {
        let sideEffects = await _store._dispatch(action: IdentityAction.setUser(User.main))
        let state = await _store._getState()
        XCTAssertEqual(sideEffects.count, 0)
        XCTAssertEqual(state.identity, .member(User.main))
    }

    func testMapping() async throws {
        let vm = ProfileViewModel()

        await _store.map(\.identity.member?.email,
                         to: &vm.$userEmail)
        let sideEffects = await _store._dispatch(action: IdentityAction.setUser(User.main))

        
        XCTAssertEqual(sideEffects.count, 0)
        for try await value in vm.$userEmail.timeout(1).asyncStream() {
            if value == User.main.email {
                return
            }
        }

        XCTFail()
    }
    
    func testPerformSideEffects() async throws {
        let sideEffects = await _store._dispatch(action: IdentityAction.logout)
        await _store._perform(sideEffects: sideEffects)
        
        XCTAssertEqual(sideEffects.count, 1)
        let environment = await _store._getEnvironment()
        
        for try await value in environment.identity.$logoutCalled.timeout(1).asyncStream() {
            if value {
                return
            }
        }
        
        XCTFail()
    }
}
