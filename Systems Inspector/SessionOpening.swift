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
    case locked(SessionNotice)
    case waiting(SessionNotice)
    case question(String)
    case unavailable(SessionNotice)
}

enum SessionLogin: Equatable {
    case started
    case waiting(SessionNotice)
    case locked(SessionNotice)
    case refused(SessionNotice)
}

enum SessionDeletion: Equatable {
    case matched
    case waiting(SessionNotice)
    case refused(SessionNotice)
}

struct SessionReset: Equatable {
    var success: Bool
    var title: String
    var message: String
}

/// Starts a Session, logs one in, resets a password, and confirms the Delete Account password.
/// Callers show the notice and do not read the Email lock.
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

    func login(email: String, password: String) async -> SessionLogin {
        if let locked = Self.lockedNotice(for: email) {
            return .locked(locked)
        }
        guard await storeReady(), let context = context() else {
            return .refused(Self.loginRefused(for: email))
        }
        switch await UserManager.shared.checkPassword(password, forEmail: email, in: context) {
        case .waiting:
            return .waiting(Self.waitingNotice)
        case .absent, .mismatch:
            AccountLockoutManager.shared.recordFailedAttempt(email: email)
            if let locked = Self.lockedNotice(for: email) {
                return .locked(locked)
            }
            return .refused(Self.loginRefused(for: email))
        case .match(let userID):
            guard UserManager.shared.beginSession(userID: userID, in: context) else {
                return .refused(Self.loginRefused(for: email))
            }
            AccountLockoutManager.shared.recordSuccessfulLogin(email: email)
            return .started
        }
    }

    func confirmDeletion(password: String) async -> SessionDeletion {
        guard await storeReady(), let context = context() else {
            return .refused(Self.deletionRefused)
        }
        switch await UserManager.shared.checkSessionPassword(password, in: context) {
        case .waiting:
            return .waiting(Self.waitingNotice)
        case .match:
            return .matched
        case .absent, .mismatch:
            return .refused(Self.deletionRefused)
        }
    }

    func recovery(for email: String) -> SessionRecovery {
        if let locked = Self.lockedNotice(for: email) {
            return .locked(locked)
        }
        switch PasswordRecoveryManager.shared.recoveryState(for: email, in: context()) {
        case .waiting:
            return .waiting(Self.waitingNotice)
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
        if let locked = Self.lockedNotice(for: email) {
            return SessionReset(success: false, title: locked.title, message: locked.message)
        }
        if case .waiting = recovery.recoveryState(for: email, in: context()) {
            return SessionReset(
                success: false,
                title: Self.waitingNotice.title,
                message: Self.waitingNotice.message
            )
        }
        let strength = recovery.validatePasswordStrength(newPassword)
        if !strength.isValid {
            return SessionReset(success: false, title: "Weak Password", message: strength.message)
        }
        switch await recovery.resetPasswordOffMain(
            for: email,
            newPassword: newPassword,
            securityAnswer: securityAnswer,
            in: context()
        ) {
        case .replaced:
            return SessionReset(success: true, title: "Success", message: "Password has been reset successfully!")
        case .writeFailed:
            return SessionReset(success: false, title: "Error", message: "Failed to reset password.")
        case .unknownEmail:
            let notice = Self.answerRefused(for: email)
            return SessionReset(success: false, title: notice.title, message: notice.message)
        case .answerRefused:
            AccountLockoutManager.shared.recordFailedAttempt(email: email)
            if let locked = Self.lockedNotice(for: email) {
                return SessionReset(success: false, title: locked.title, message: locked.message)
            }
            let notice = Self.answerRefused(for: email)
            return SessionReset(success: false, title: notice.title, message: notice.message)
        }
    }

    static let waitingNotice = SessionNotice(
        title: SessionSecretMessage.waitingTitle,
        message: SessionSecretMessage.waiting
    )

    static let deletionRefused = SessionNotice(
        title: "Authentication Failed",
        message: "Invalid password. Account deletion cancelled."
    )

    static func lockedNotice(for email: String) -> SessionNotice? {
        let lockout = AccountLockoutManager.shared
        guard lockout.isAccountLocked(email: email) else { return nil }
        let remaining = lockout.formatRemainingTime(lockout.getRemainingLockoutTime(email: email))
        return SessionNotice(
            title: "Account Locked",
            message: "Too many failed attempts. Try again in \(remaining)."
        )
    }

    static func loginRefused(for email: String) -> SessionNotice {
        SessionNotice(
            title: "Login Failed",
            message: "Invalid email or password.\n\(attemptsLeft(for: email))"
        )
    }

    static func answerRefused(for email: String) -> SessionNotice {
        SessionNotice(
            title: "Error",
            message: "Security answer is incorrect. \(attemptsLeft(for: email))"
        )
    }

    private static func attemptsLeft(for email: String) -> String {
        let remaining = AccountLockoutManager.shared.getRemainingAttempts(email: email)
        let noun = remaining == 1 ? "attempt" : "attempts"
        return "\(remaining) \(noun) remaining before account lockout."
    }
}
