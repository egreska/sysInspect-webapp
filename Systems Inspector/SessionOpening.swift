//
//  SessionOpening.swift
//  Systems Inspector
//

import CoreData
import Foundation

struct SessionNotice: Equatable {
    var title: String
    var message: String
}

enum SessionStart: Equatable {
    case started(SessionNotice)
    case claimPending(SessionNotice)
    case refused(SessionNotice)
}

enum SessionRecovery: Equatable {
    case locked(String)
    case waiting(SessionNotice)
    case question(String)
    case unavailable(SessionNotice)
}

struct SessionReset: Equatable {
    var success: Bool
    var title: String
    var message: String
}

/// Starts a Session, tells a reset screen what an email can do, and resets a password.
@MainActor
struct SessionOpening {
    var context: () -> NSManagedObjectContext?
    var storeReady: () async -> Bool
    var markClaim: () async -> Bool

    static let live = SessionOpening(
        context: {
            guard CoreDataManager.shared.isStoreLoaded else { return nil }
            return CoreDataManager.shared.context
        },
        storeReady: {
            await withCheckedContinuation { continuation in
                CoreDataManager.shared.waitForStoreToLoad { ready in
                    continuation.resume(returning: ready)
                }
            }
        },
        markClaim: { await ClaimCheck.shared.sessionExists() }
    )

    static let claimPendingMessage = "Session started. This iPad could not update the Claim yet."
    static let emailTakenMessage = "An account with this email already exists locally. Please try logging in or using a different email."
    static let couldNotStartMessage = "Failed to create account. Please check your internet connection and try again. If the problem persists, this email might already be registered."

    func start(
        email: String,
        password: String,
        securityQuestion: String,
        securityAnswer: String
    ) async -> SessionStart {
        let recovery = PasswordRecoveryManager.shared
        let strength = recovery.validatePasswordStrength(password)
        if !strength.isValid {
            return .refused(SessionNotice(title: "Weak Password", message: strength.message))
        }
        let answer = recovery.validateSecurityAnswer(securityAnswer)
        if !answer.isValid {
            return .refused(SessionNotice(title: "Error", message: answer.message))
        }
        guard await storeReady(), let context = context() else {
            return .refused(SessionNotice(title: "Account Creation Failed", message: Self.couldNotStartMessage))
        }
        if UserManager.shared.userExists(email: email, in: context) {
            return .refused(SessionNotice(title: "Error", message: Self.emailTakenMessage))
        }
        let created = await UserManager.shared.performUserCreationOffMain(
            email: email,
            password: password,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            in: context
        )
        guard created else {
            return .refused(SessionNotice(title: "Account Creation Failed", message: Self.couldNotStartMessage))
        }
        let marked = await markClaim()
        if marked {
            return .started(SessionNotice(
                title: "Account Created",
                message: "Your account has been successfully created with password recovery!"
            ))
        }
        return .claimPending(SessionNotice(title: "Account Created", message: Self.claimPendingMessage))
    }

    func recovery(for email: String) -> SessionRecovery {
        if let locked = PasswordRecoveryManager.shared.lockMessage(for: email) {
            return .locked(locked)
        }
        switch PasswordRecoveryManager.shared.recoveryState(for: email, in: context()) {
        case .waiting:
            return .waiting(SessionNotice(
                title: SessionSecretMessage.waitingTitle,
                message: SessionSecretMessage.waiting
            ))
        case .question(let question):
            return .question(question)
        case .unavailable:
            return .unavailable(SessionNotice(
                title: "Security Question Not Set",
                message: "This account doesn't have a security question set up. Please contact support or create a new account."
            ))
        }
    }

    func reset(email: String, newPassword: String, securityAnswer: String) async -> SessionReset {
        guard await storeReady() else {
            return SessionReset(success: false, title: "Error", message: "Failed to reset password.")
        }
        let recovery = PasswordRecoveryManager.shared
        if let locked = recovery.lockMessage(for: email) {
            return SessionReset(success: false, title: "Error", message: locked)
        }
        if case .waiting = recovery.recoveryState(for: email, in: context()) {
            return SessionReset(success: false, title: "Error", message: SessionSecretMessage.waiting)
        }
        let strength = recovery.validatePasswordStrength(newPassword)
        if !strength.isValid {
            return SessionReset(success: false, title: "Weak Password", message: strength.message)
        }
        let result = await recovery.resetPasswordOffMain(
            for: email,
            newPassword: newPassword,
            securityAnswer: securityAnswer,
            in: context()
        )
        return SessionReset(
            success: result.success,
            title: result.success ? "Success" : "Error",
            message: result.message
        )
    }
}
