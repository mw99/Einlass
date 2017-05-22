//
//                Apache License, Version 2.0
//
//  Copyright 2017, Markus Wanke
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


import Foundation
import Accounts

/// Abstract helper class to provide common functionality for the
/// authentication procedure of multiple SNS authentication services.
open class SocialBaseAuthenticator
{
    private let store = ACAccountStore()
    
    internal typealias JSONObj = [String: AnyObject]
    
    
    internal enum AccountStoreResult
    {
        case success([ACAccount])
        case accessNotGranted
        case noSystemAccounts
        case accountStoreError(String)
    }
    
    internal enum AuthProvider
    {
        case facebook
        case twitter
        
        var accountStoreIdentifier: String {
            switch self {
                case .facebook:  return ACAccountTypeIdentifierFacebook
                case .twitter:   return ACAccountTypeIdentifierTwitter
            }
        }
    }

    // Does need to be public or else subclasses can't be instanced outside of the module.
    public init() {}
    

    /// The error codes of `requestAccessToAccounts:with:` are not documented anywhere and 
    /// behave very strange depending on: 
    ///   1) if the popup is shown or not
    ///   2) is shown for the first time and 
    ///   3) for what kind of account type. 
    /// Lots of trial and error went into this. And more is probably needed.
    /// - Parameters:
    ///   - error: error from `requestAccessToAccounts:with:`
    ///   - and: continuation callback from `allAccountsFor:accountsType:`
    internal func handleAccountAccessRequest(error: NSError, and: @escaping (AccountStoreResult)->())
    {
        // The error codes of this function are not documented anywhere and behave very strange
        // depending on if the popup is shown or not, is shown for the first time and for what
        // kind of account type. Lots of trial and error went into this.
        
        switch error.code {
            case 6: // Undocumented, however code 6 = no accounts, but only for facebook.
                and(.noSystemAccounts)
            case 7: // and code 7 is a little bit more tricky
                if error.userInfo.isEmpty {
                    // This inconsistency happens when the facebook access popup is the first time denied.
                    and(.accessNotGranted)
                }
                else {
                    // This can happen in a lot of cases I presume. wrong bundle identifier for facebook etc.
                    and(.accountStoreError("\(error)"))
                }
                
            default:
                and(.accountStoreError("\(error)"))
        }
    }

    
    /// Helper function to access all system accounts for a certain authentication provider.
    ///
    /// - Parameters:
    ///   - provider: authentication provider (.facebook or .twitter)
    ///   - options: provider specific options (facebook publish right etc.)
    ///   - and: continuation callback with a result
    internal func allAccountsFor(provider: AuthProvider, options: [AnyHashable : Any]? = nil, and: @escaping (AccountStoreResult)->())
    {
        let type = store.accountType(withAccountTypeIdentifier: provider.accountStoreIdentifier)!
        
        store.requestAccessToAccounts(with: type, options: options) { granted, error in
            
            if let error = error {
                self.handleAccountAccessRequest(error: error as NSError, and: and)
            }
            else if !granted {
                and(.accessNotGranted)
            }
            else {
                let res: [ACAccount] = self.store.accounts(with: type).flatMap { $0 as? ACAccount }
                and( res.isEmpty ? .noSystemAccounts : .success(res))
            }
        }
    }
    
    
    /// Needs to be called when the iOS internal Facebook token has expired. It seems to be 
    /// not necessary for twitter accounts.
    ///
    /// - Parameters:
    ///   - account: Account to renew
    ///   - and: Continue callback which will be called with an account or an error massage
    internal func renew(account: ACAccount, and: @escaping (ACAccount?, String?)->())
    {
        store.renewCredentials(for: account) { result, error in
            
            if let error = error {
                and(nil, error.localizedDescription)
            }
            else if result != ACAccountCredentialRenewResult.renewed {
                and(nil, "Account could not be renewed" )
            }
            else {
                and(account, nil)
            }
        }
    }

    internal func toJSONObj(from: Data) -> JSONObj?
    {
        return (try? JSONSerialization.jsonObject(with: from, options: [])) as? JSONObj
    }
}

