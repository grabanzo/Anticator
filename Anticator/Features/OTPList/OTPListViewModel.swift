//
//  OTPListViewModel.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class OTPListViewModel {
    var currentTime = Date()
    private(set) var copiedAccountId: UUID?
    
    private var timerTask: Task<Void, Never>?
    private let otpGenerator = OTPGeneratorService.shared
    private let otpAccountService = OTPAccountService.shared
    private let logger = Logger(subsystem: "org.grabanzo.Anticator", category: "OTPList")
    
    func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                currentTime = Date()
            }
        }
    }
    
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    func refresh() {
        currentTime = Date()
    }
    
    func generateCode(for account: OTPAccount) -> String? {
        do {
            let secret = try otpAccountService.getSecret(for: account)
            return try otpGenerator.generateCode(for: account, secret: secret, date: currentTime)
        } catch {
            logger.error("Error generating code: \(error.localizedDescription)")
            return nil
        }
    }
    
    func secondsRemaining(for account: OTPAccount) -> Int {
        otpGenerator.secondsRemaining(period: account.period, date: currentTime)
    }
    
    func progress(for account: OTPAccount) -> Double {
        otpGenerator.progress(period: account.period, date: currentTime)
    }
    
    func showCopiedFeedback(for id: UUID) {
        copiedAccountId = id
        
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedAccountId == id {
                copiedAccountId = nil
            }
        }
    }
    
    func isCopied(_ id: UUID) -> Bool {
        copiedAccountId == id
    }
}

