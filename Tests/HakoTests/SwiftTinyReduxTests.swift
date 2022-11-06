//
//  HakoTests.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Combine
@testable import Hako
import XCTest

@MainActor
final class HakoTests: XCTestCase {
    func testSimpleDispatch() {
        let context = Store()
        context.dispatch(.setUser(.main))
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testPublishedState() async {
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let context = Store()
        context.state.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.dispatch(.setUser(.main))
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(context.state.account, .member(User.main))
    }

    func testAsyncSequenceIngest() {
        var count = 0
        let expectation = XCTestExpectation()
        var cancellables: Set<AnyCancellable> = []
        let stream: CurrentValueSubject<Mutation, Never> = .init(.setUser(.main))
        let context = Store()
        context.state.objectWillChange
            .sink { _ in
                count += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        context.ingest(stream)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(count, 1)
    }

    func testAsyncSideEffectGroup() async {
        let context = Store()
        await context.perform(.parallelLogin)
        XCTAssertEqual(context.state.account, .member(User.main))
    }
}
