/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// User profile data stored in Firestore /users/{userId}
struct UserProfile: Codable, Equatable {
    var firstName: String
    var lastName: String
    var email: String?
    
    // Notification preferences
    var pushNotificationsEnabled: Bool
    var emailNotificationsEnabled: Bool
    var marketingOptIn: Bool
    
    // Timestamps
    var createdAt: Date?
    var updatedAt: Date?
    
    init(
        firstName: String = "",
        lastName: String = "",
        email: String? = nil,
        pushNotificationsEnabled: Bool = true,
        emailNotificationsEnabled: Bool = true,
        marketingOptIn: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.marketingOptIn = marketingOptIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var displayName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
