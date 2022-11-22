# Hako

[![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Hako is a barebone, thread-safe Redux-like container for Swift. It features a minimal API and supports composable reducers. It was designed to bring Redux's core idea to Swift. You can find an article outlining the motivation behind it and the way it works internally [here](https://swiftcraft.io/blog/how-to-build-a-redux-container-from-scratch-in-swift). This minimal README.md assumes prior Redux (or TCA) knowledge.

To set up a container using multiple reducers:


```swift
let bootstrapReducer: Reducer<AppState, AppAction, AppEnvironment> = { state, action in
    switch action {
    case .didBecomeActive:
        state.phase = .active
        state.navigation.history = ["/launching"]
        return { env, dispatch in
            it let user = await env.identity.fetchUser() {
                dispatch(IdentityAction.setUser(user))
                dispatch(NavigationAction.present("/dashboard"))
            }
            else {
                dispatch(NavigationAction.present("/gatekeeper"))
            }
        } 
    }
}

let navigationReducer: Reducer<NavigationState, NavigationAction, NavigationEnvironment> = { state, action in
    switch action {
    case let .present(path):
        state.history.append(path)
    case .dismiss:
        if state.history.count > 0 {
            state.history.removeLast()
        } 
    }
}

let initialState = AppState()
let env = AppEnvironment()
let store = MainStore(initialState: initialState,
                      env: env)
store.add(reducer: bootstrapReducer)
store.add(reducer: navigationReducer,
          state: \.navigation,
          env: \.navigation)
          
// Later on, map any state key path to interested parties.
store.map(\.navigation.history.last, to: &viewmodel.$currentPath)
```
