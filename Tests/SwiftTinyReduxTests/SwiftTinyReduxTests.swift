//
//  SwiftTinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

@testable import SwiftTinyRedux
import XCTest

final class SwiftTinyReduxTests: XCTestCase {
    private var _store: Store<AppState, AppEnvironment>!
    private var _context: StoreContext<AppState, AppEnvironment>!

    override func setUp() {
        let state: AppState = .init(identity: .guest, errors: [])
        let env: AppEnvironment = .init(identity: .init())
        let errorSideEffect = AnyErrorSideEffect { error, store in
            store.dispatch(action: ShowAlert(error: error))
        }
        _context = StoreContext(state: state, environment: env)
        _store = Store(context: _context, errorSideEffects: [errorSideEffect])
    }

    func testSimpleDispatch() {
        let store = _store.partial(state: \.identity, environment: \.identity)
        let sideEffects = store._dispatch(action: SetUserAction(user: .main))

        XCTAssertNil(sideEffects)
        XCTAssertEqual(store.state, .member(User.main))
    }

    func testThrowDispatch() async {
        let sideEffect: AppSideEffect = { _, _ in
            throw IdentityError.unauthenticated
        }
        let store = _store.partial(state: \.self, environment: \.self)
        await store._perform(sideEffect: sideEffect)

        let state = _store.state
        XCTAssertEqual(state.errors.compactMap { $0 as? IdentityError },
                       [IdentityError.unauthenticated])
    }

//    func testPublishedState() async throws {
//        let store = _store.partial(state: \.identity, environment: \.identity)
//        var
//        _context.objectWillChange
//            .sink {
//                if _context.state.identity == .member(.main) {
//                    return
//                }
//            }
//        
//        store.dispatch(action: SetUserAction(user: .main))
//
//        for try await _ in .values {
//            
//        }
//        
//        XCTFail()
//    }

//    func testMapping() async throws {
//        let vm = ProfileViewModel()
//
//        _store
//            .watch(\.identity.member?.email)
//            .assign(to: &vm.$userEmail)
//        let sideEffects = _store._dispatch(action: IdentityAction.setUser(User.main))
//
//        XCTAssertEqual(sideEffects.count, 0)
//        for try await value in vm.$userEmail.timeout(1).asyncStream() {
//            if value == User.main.email {
//                return
//            }
//        }
//
//        XCTFail()
//    }
//
//    func testPerformSideEffects() async throws {
//        let sideEffects = _store._dispatch(action: IdentityAction.logout)
//        await _store._perform(sideEffects: sideEffects)
//
//        XCTAssertEqual(sideEffects.count, 1)
//        let environment = _store.environment
//
//        for try await value in environment.identity.$logoutCalled.timeout(1).asyncStream() {
//            if value {
//                return
//            }
//        }
//
//        XCTFail()
//    }
//
//    func testMultithreadDispatch() async throws {
//        let vm = ProfileViewModel()
//        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
//
//        _store
//            .watch(\.identity.member?.likes)
//            .assign(to: &vm.$likes)
//
//        _ = _store._dispatch(action: IdentityAction.setUser(User.main))
//
//        for _ in 0 ..< 100 {
//            queue.async { [unowned self] in
//                _ = _store._dispatch(action: IdentityAction.like)
//            }
//        }
//
//        for try await value in vm.$likes.timeout(1).asyncStream() {
//            if value == 100 {
//                return
//            }
//        }
//
//        XCTFail()
//    }
}
