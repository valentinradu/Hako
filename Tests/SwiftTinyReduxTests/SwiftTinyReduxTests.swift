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
        context.willChange {}
        context.dispatch(.setUser(.main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let context = Store()
        var wasCalledOnMainThread = false
        context.willChange {
            wasCalledOnMainThread = Thread.isMainThread
        }

        context.dispatch(.setUser(.main))

        XCTAssertTrue(wasCalledOnMainThread)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testMultithreadDispatch() async {
        let context = Store(state: .init(account: .member(.main), errors: []))
        let queue = DispatchQueue(label: "com.swifttinyredux.test", attributes: .concurrent)
        let expectation = XCTestExpectation()
        var likeCount = 0
        context.willChange {
            likeCount += 1
            if likeCount == 100 {
                expectation.fulfill()
            }
        }

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
        context.ingest(stream)

        context.willChange {
            count += 1
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(count, 1)
    }

    func testAsyncSideEffectGroup() {
        let context = Store()
        let expectation = XCTestExpectation()
        
        context.willChange {
            expectation.fulfill()
        }
        
        context.dispatch(.parallelLogin)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }
}
