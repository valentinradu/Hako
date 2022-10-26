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
    func testSimpleDispatch() {
        let context = Store()
        context.willChange { _ in }
        context.didChange { _ in }
        context.dispatch(.setUser(.main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let context = Store()
        context.willChange { _ in }
        context.didChange { _ in }

        context.dispatch(.setUser(.main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testMultithreadDispatch() async {
        let context = Store(state: .init(account: .member(.main), errors: []))
        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
        let expectation = XCTestExpectation()
        var likeCount = 0
        context.willChange { _ in
            likeCount += 1
            if likeCount == 100 {
                expectation.fulfill()
            }
        }
        context.didChange { _ in }

        for _ in 0 ..< 100 {
            queue.async {
                context.dispatch(.like)
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func testAsyncSequenceIngest() {
        var count = 0
        let expectation = XCTestExpectation()
        let stream = AsyncStream<Mutation<IdentityState, IdentityEnvironment>> {
            .setUser(.main)
        }
        let context = Store()
        context.willChange { _ in
            count += 1
            expectation.fulfill()
        }
        context.didChange { _ in }
        context.ingest(stream)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(count, 1)
    }

    func testAsyncSideEffectGroup() {
        let context = Store()
        let expectation = XCTestExpectation()

        context.willChange { _ in
            expectation.fulfill()
        }
        context.didChange { _ in }
        context.dispatch(.parallelLogin)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }
}
