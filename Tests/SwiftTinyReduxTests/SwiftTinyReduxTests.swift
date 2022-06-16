//
//  SwiftTinyReduxTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
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

    func testPublishedState() async throws {
        let store = _store.partial(state: \.identity, environment: \.identity)
        var cancellables: Set<AnyCancellable> = []
        var wasCalledOnMainThread = false
        _context.objectWillChange
            .sink {
                wasCalledOnMainThread = Thread.isMainThread
            }
            .store(in: &cancellables)

        store.dispatch(action: SetUserAction(user: .main))

        XCTAssertTrue(wasCalledOnMainThread)
        XCTAssertEqual(store.state, .member(User.main))
    }

    func testPerformSideEffects() async throws {
        let store = _store.partial(state: \.identity, environment: \.identity)
        var cancellables: Set<AnyCancellable> = []
        var logoutCalled = false
        store.environment.$logoutCalled
            .sink {
                logoutCalled = $0
            }
            .store(in: &cancellables)

        guard let sideEffect = store._dispatch(action: LogoutAction()) else {
            XCTFail()
            return
        }

        await store._perform(sideEffect: sideEffect)

        XCTAssertTrue(logoutCalled)
    }
    
    func testCustomDispatch() async throws {
        var action = LogoutAction()
        let store = Store(context: _context) {
            action = $0
        }
        let identityStore = store.partial(state: \.identity, environment: \.identity)
        
        identityStore.dispatch(action: LikeAction())
        
        
    }

    func testMultithreadDispatch() async throws {
        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
        var cancellables: Set<AnyCancellable> = []
        let expectation = XCTestExpectation()
        var likeCount = 0
        _context.objectWillChange
            .sink {
                likeCount += 1
                if likeCount == 100 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let store = _store.partial(state: \.identity, environment: \.identity)

        for _ in 0 ..< 100 {
            queue.async {
                store.dispatch(action: LikeAction())
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
