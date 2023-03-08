//
//  File.swift
//
//
//  Created by Valentin Radu on 28/01/2023.
//

import Hako

// Fragments are roughly one to one with app screens,
// although they could also be partial sheets, alerts and so on.
enum NavigationFragment {
    case onboardingWelcome
    case onboardingAskEmail
    case onboardingAskPassword
    case onboardingCreateAccount
    case onboardingLocateUser
    case onboardingSuggestions
}

// This stores the navigation state (currently presented fragments)
struct NavigationState {
    var path: [NavigationFragment]
}

// Used to mutate the navigation state
enum NavigationAction {
    case present(NavigationFragment)
    case dismiss
}
