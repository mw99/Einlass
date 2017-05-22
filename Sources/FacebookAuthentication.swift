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
import Social
import Accounts


/// Once at app startup `FacebookAuthenticator.consumerCredentialProvider` should be set to
/// a class or struct that conforms to this protocol. Normally you would use your struct
/// for global constants.
/// Example: `FacebookAuthenticator.consumerCredentialProvider = Const.self`
public protocol FacebookConsumerCredentialProvider
{
    /// The App ID assigned by Facebook. Can be found under [Facebook App Dashboard](https://developers.facebook.com/apps/)
    static var FACEBOOK_APP_ID: String { get }
}


/// To receive authentication results or possible errors, as well as enable account selection,
/// set `FacebookAuthenticator().delegate` to a class that conforms to this protocol.
public protocol FacebookAuthenticatorDelegate: class
{
    /// This function will be called on the delegate when the authentication procedure was successful.
    ///
    /// - Parameter withCredentials: The user credentials containing: 
    ///         1) the Facebook ID
    ///         2) the real name
    ///         3) the authentication token 
    ///         4) maybe the users e-mail address (some users only register with their phone number etc.)
    ///         5) an url to the users Facebook avatar
    /// The token can now be used for server side validation or further requests to the Facebook
    /// graph API on behalf of the user.
    func facebookAuthenticatorFinished(withCredentials: FacebookAuthenticator.Credentials)
    
    
    /// This function will be called on the delegate when the authentication procedure failed.
    ///
    /// - Parameter withProblem: Enum type that divides the various errors
    ///                          in recoverable and non recoverable error codes.
    func facebookAuthenticatorFinished(withProblem: FacebookAuthenticator.Problem)
    
    
    /// The purpose of this function is to confirm that the user really wants to proceed the login 
    /// procedure with his/her Facebook account that is registered under iOS settings.
    ///
    /// - Parameters:
    ///   - withAccount: Identifier string that the user should recognize. Normally the email 
    ///                  address or telephone number of their Facebook account.
    ///   - proceed: Continuation callback. Calling it with false will lead to
    ///              `userCanceledAccountSelection` being passed to the delegate.
    func facebookAccountConfirmation(withAccount: String, proceed: @escaping (Bool)->())
}


/// Class that provides easy authentication with the Facebook account registered under iOS settings.
open class FacebookAuthenticator: SocialBaseAuthenticator
{
    /// Facebook app id provider. Should be set at app initialization.
    open static var consumerCredentialProvider: FacebookConsumerCredentialProvider.Type? = nil
    
    /// Callback delegate for receiving credentials and errors.
    open weak var delegate: FacebookAuthenticatorDelegate?
    
    /// Access permissions that will be assigned to the received Facebook authentication token.
    /// [Related Documentation](https://developers.facebook.com/docs/facebook-login/permissions)
    /// An empty array defaults internally to:
    /// "user_birthday", "user_location", "user_friends", "email", "public_profile"
    open var permissions: [String] = []
    
    /// If the returned authentication token is used for posting content on facebook, the 
    /// audience limit should be set accordingly. Default: .onlyMe
    open var audience: Audience = .onlyMe

    /// Enum to define the target audience when the Facebook token is used to post contend on Facebook.
    public enum Audience
    {
        case onlyMe
        case friends
        case everyone
        
        var accountStoreKey: String {
            switch self {
                case .onlyMe:    return ACFacebookAudienceOnlyMe
                case .friends:   return ACFacebookAudienceFriends
                case .everyone:  return ACFacebookAudienceEveryone
            }
        }
    }
    
    /// Passed to the delegate after an successful authentication.
    public struct Credentials
    {
        public let id: String
        public let name: String
        public let token: String
        public let email: String?
        public let avatar: URL
    }
    
    /// Passed to the delegate when the authentication flow aborted due to one of the various possible errors.
    public enum Problem: Error
    {
        /// Occurs when there is no Facebook account registered under iOS settings.
        case noSystemFacebookAccount
        
        /// Occurs when the user has denied access to the system Facebook account.
        case facebookAccountAccessNotGranted
        
        /// Occurs when the `facebookAccountSelection:withAccount:proceed:` callback was called with `false`.
        case userCanceledAccountSelection
        
        /// Occurs when the Facebook account under iOS settings is not useable and not renewable anymore. (banned etc.)
        case systemAccountReloginNeeded
        
        /// Occurs when `consumerCredentialProvider` was not set during app initialization.
        case facebookAuthenticatorUnconfigured
        
        /// Occurs on network failures.
        case networkFailure(Int, String)
        
        /// General error for Facebook communication failure. If you experience these and they seem recoverable, it
        /// would be desirable to report them as bugs on the github issue tracker of this project.
        case facebookFailure(String)
        
        /// General error for iOS account store failure. If you experience these and they seem recoverable, it
        /// would be desirable to report them as bugs on the github issue tracker of this project.
        case accountStoreFailure(String)
    }
    
    
    private var choosenAccount: ACAccount?
    private var renewalTried: Bool = false
    private var reauthTried: Bool  = false

    
    /// Initiate the Facebook authentication procedure, which will finally result in calling either
    /// `facebookAuthenticatorFinished:withCredentials:` or `facebookAuthenticatorFinished:withProblem:`
    /// on the delegate. On the condition that `facebookAccountSelection:withAccount:proceed:`
    /// is correctly implemented. Also avoid calling `perform()` a second time on the same instance 
    /// since that behaviour is undefined. You should always create a new instance
    /// of `FacebookAuthenticator` to call `perform()` again.
    open func perform()
    {
        guard let appID = FacebookAuthenticator.consumerCredentialProvider?.FACEBOOK_APP_ID else {
            problem(.facebookAuthenticatorUnconfigured)
            return
        }
        
        let options: [AnyHashable : Any] = [
            ACFacebookAppIdKey:       appID,
            ACFacebookPermissionsKey: permissions as NSArray,
            ACFacebookAudienceKey:    audience.accountStoreKey
        ]
        
        allAccountsFor(provider: .facebook, options: options) { 
            
            switch ($0) {
                case .accessNotGranted:
                    self.problem(.facebookAccountAccessNotGranted)
                case .noSystemAccounts:
                    self.problem(.noSystemFacebookAccount)
                case .accountStoreError(let message):
                    self.problem(.accountStoreFailure(message))
                case .success(let accounts):
                    guard !accounts.isEmpty else {
                        self.problem(.noSystemFacebookAccount)
                        return
                    }
                    self.handle(account: accounts.first!)
            }
        }
    }
    
    
    private func handle(account: ACAccount)
    {
        DispatchQueue.main.async {
            self.delegate?.facebookAccountConfirmation(withAccount: account.username) { proceed in
                
                guard proceed else {
                    self.problem(.userCanceledAccountSelection)
                    return
                }
                
                self.choosenAccount = account
                self.performWholeAuthCyle(withAccount: account)
            }
        }
    }
    
    
    private func performWholeAuthCyle(withAccount account: ACAccount?)
    {
        // reference https://developers.facebook.com/docs/graph-api/reference/user
        let url: URL = URL(string: "https://graph.facebook.com/v2.8/me")!
        
        let options: [AnyHashable : Any] = ["fields": "id,name,email"]
        
        let request = SLRequest(forServiceType: SLServiceTypeFacebook, requestMethod: .GET, url: url, parameters: options)!
        request.account = account
        
        request.perform { data, response, error in
            
            guard error == nil else {
                let e = error! as NSError
                self.problem(.networkFailure(e.code, e.localizedDescription))
                return
            }
            
            guard let data = data, let response = response else { // should never happen
                self.problem(.facebookFailure("No data and no error received from Facebook."))
                return
            }
            
            self.handleAuthResponse(withStatusCode: response.statusCode, data: data)
        }
    }

    
    private func handleAuthResponse(withStatusCode statusCode: Int, data: Data)
    {
        guard let parsedJSON = toJSONObj(from: data) else {
            self.problem(.facebookFailure("JSON response not parsable."))
            return
        }
        
        guard statusCode >= 200 && statusCode < 300 else {
            
            if let fberror = parseErrorResponse(from: parsedJSON) {
                handle(fberror)
            }
            else {
                self.problem(.facebookFailure("Facebook server returned status code: \(statusCode)"))
            }
            return
        }
        
        guard
            let token   =  choosenAccount?.credential.oauthToken,
            let id      =  parsedJSON["id"] as? String,
            let name    =  parsedJSON["name"] as? String,
            let avatar  =  URL(string: "https://graph.facebook.com/\(id)/picture?type=large")
        else {
            self.problem(.facebookFailure("SL-Request response does not contain the requested data."))
            return
        }
        
        let maybeEmail =  parsedJSON["email"] as? String
        
        let cred = Credentials(id: id, name: name, token: token, email: maybeEmail, avatar: avatar)
        
        DispatchQueue.main.async {
            self.delegate?.facebookAuthenticatorFinished(withCredentials: cred)
        }
    }


    private func handle(_ fberr: FBError)
    {
        // [docu](https://developers.facebook.com/docs/facebook-login/access-tokens/debugging-and-error-handling)
        
        if !reauthTried, fberr.code == 190, let sub = fberr.subCode, sub == 458 {
            reauthTried = true
            // app permission revoked. we perform one retry to get the auth popup to show again
            perform()
        }
        else if !renewalTried, fberr.code == 190 {
            // ios system token has expired, or the user has changed his/her password
            renewalTried = true
            tryTokenRenewal()
        }
        else {
            problem(.facebookFailure(fberr.description))
        }
    }


    private func tryTokenRenewal()
    {
        renew(account: choosenAccount!) { renewedAccount, errorMessage in
            
            if errorMessage != nil {
                self.problem(.systemAccountReloginNeeded) // user has changed password
            }
            else {
                self.performWholeAuthCyle(withAccount: renewedAccount!)
            }
        }
    }
    
    
    private struct FBError: CustomStringConvertible
    {
        let code: Int
        let msg: String
        let type: String
        let subCode: Int?
        
        public var description: String {
            if let sc = subCode {
                return "Facebook Error: Code:\(code), SubCode:\(sc), Type:\(type), Message:\(msg)"
            }
            else {
                return "Facebook Error: Code:\(code), Type:\(type), Message:\(msg)"
            }
        }
    }
    
    
    private func problem(_ prob: Problem)
    {
        DispatchQueue.main.async {
            self.delegate?.facebookAuthenticatorFinished(withProblem: prob)
        }
    }
    
    
    private func parseErrorResponse(from: JSONObj) -> FBError?
    {
        guard let estruct = from["error"] as? JSONObj else {
            return nil
        }
        
        guard
            let code  = estruct["code"] as? Int,
            let type  = estruct["type"] as? String,
            let msg   = estruct["message"] as? String
        else {
            return nil
        }
        
        return FBError(code: code, msg: msg, type: type, subCode: estruct["error_subcode"] as? Int)
    }
}

