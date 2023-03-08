//
//  Fixtures.swift
//
//
//  Created by Valentin Radu on 22/05/2022.
//

import Hako

// This stores the state of all the text fields and values
// required for the purpose of authentication and onboarding
struct OnboardingState {}

// These actions mutate the onboarding state
enum OnboardingAction {
    case inputEmail(String)
    case inputPassword(String)
    case inputFullName(String)
    case togglePasswordVisiblity
    case nextStep
    case prevStep
    case signUp
    case login
    case navigateToLogin
    case navigateToSignUp
    case locateMe
    case finish
}
