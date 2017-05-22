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
import OhhAuth


/// Once at app startup `TwitterAuthenticator.consumerCredentialProvider` should be set to
/// a class or struct that conforms to this protocol. Normally you would use your struct
/// for global constants.
/// Example: `TwitterAuthenticator.consumerCredentialProvider = Const.self`
public protocol TwitterConsumerCredentialProvider
{
    /// The app consumer key assigned by Twitter. Can be found under [Twitter App Dashboard](https://apps.twitter.com/)
    static var TWITTER_CONSUMER_KEY: String { get }
    
    /// The app consumer secret assigned by Twitter. Can be found under [Twitter App Dashboard](https://apps.twitter.com/)
    static var TWITTER_CONSUMER_SECRET: String { get }
}

/// To receive authentication results or possible errors, as well as enable account selection,
/// set `TwitterAuthenticator().delegate` to a class that conforms to this protocol.
public protocol TwitterAuthenticatorDelegate: class
{
    /// This function will be called on the delegate when the authentication procedure was successful.
    ///
    /// - Parameter withCredentials: The users credentials containing:
    ///         1) the Twitter ID
    ///         2) the Twitter name
    ///         3) the Twitter screen name
    ///         4) the authentication key & secret
    ///         5) maybe the users e-mail address (some users only register thier phone numbers etc.)
    ///         6) an url to the users Twitter avatar
    ///     The key and secret credentials can now be used for server side authentication validation 
    ///     or further requests to the Twitter API.
    /// Note: Receiving the users e-mail address from Twitter is quite complicated. You have
    ///       to set links to your companies privacy policy as well as terms of use. After that
    ///       a special settings in the Twitter app developer page has to be enabled.
    func twitterAuthenticatorFinished(withCredentials: TwitterAuthenticator.Credentials)
    
    /// This function will be called on the delegate when the authentication procedure failed.
    ///
    /// - Parameter withProblem: Enum type that divides the various errors
    ///                          in recoverable and non recoverable error codes.
    func twitterAuthenticatorFinished(withProblem: TwitterAuthenticator.Problem)
    
    /// Since the user could have set multiple Twitter accounts in his/her iOS settings, this function
    /// is called on the delegate to let the user choose one of them or cancel the authentication
    /// procedure.
    ///
    /// - Parameters:
    ///   - withAccounts: Array containing the usernames of all Twitter accounts registered in iOS.
    ///   - choice: Continuation callback. Calling it with `nil` or a string that was not contained in
    ///   the `withAccounts` array, leads to `userCanceledAccountSelection` being passed to the delegate.
    func twitterAccountSelection(withAccounts: [String], choice: @escaping (String?)->())
}


/// Class that provides easy authentication with the Twitter account registered under iOS settings.
open class TwitterAuthenticator: SocialBaseAuthenticator
{
    /// Twitter consumer credential provider. Should be set at app initialization.
    open static var consumerCredentialProvider: TwitterConsumerCredentialProvider.Type? = nil
    
    /// Callback delegate for receiving credentials and errors.
    open weak var delegate: TwitterAuthenticatorDelegate?

    /// Passed to the delegate after an successful authentication.
    public struct Credentials
    {
        public let id: String
        public let name: String
        public let screenName: String
        public let key: String
        public let secret: String
        public let email: String?
        public let avatar: URL
    }
    
    /// Passed to the delegate when the authentication flow aborted due to one of the various possible errors.
    public enum Problem: Error
    {
        /// Occurs when there is no Twitter account registered under iOS settings.
        case noSystemTwitterAccount
        
        /// Occurs when the user has denied access to the system Twitter account.
        case twitterAccountAccessNotGranted
        
        /// Occurs when the `twitterAccountSelection:withAccounts:choice:` callback was called with `nil`.
        case userCanceledAccountSelection
        
        /// Occurs when `consumerCredentialProvider` was not set during app initialization.
        case twitterAuthenticatorUnconfigured
        
        /// Occurs when the users Twitter account was banned.
        case twitterAccountBanned
        
        /// Occurs on network failures.
        case networkFailure(Int, String)
        
        /// General error for Twitter communication failure. If you experience these and they seem recoverable, it
        /// would be desirable to report them as bugs on the github issue tracker of this project.
        case twitterFailure(String)
        
        /// General error for iOS account store failure. If you experience these and they seem recoverable, it
        /// would be desirable to report them as bugs on the github issue tracker of this project.
        case accountStoreFailure(String)
    }
    

    private var consumerCredentials: (key: String, secret: String)!
    private var choosenAccount: ACAccount?
    
    /// Initiate the Twitter authentication procedure, which will finally result in calling either
    /// `twitterAuthenticatorFinished:withCredentials:` or `twitterAuthenticatorFinished:withProblem:`
    /// on the delegate. On the condition that `twitterAccountSelection:withAccounts:choice:`
    /// is correctly implemented. Also avoid calling `perform()` a second time on the same instance
    /// since that behaviour is undefined. You should always create a new instance
    /// of `TwitterAuthenticator` to call `perform()` again.
    open func perform()
    {
        guard
            let key = TwitterAuthenticator.consumerCredentialProvider?.TWITTER_CONSUMER_KEY,
            let sec = TwitterAuthenticator.consumerCredentialProvider?.TWITTER_CONSUMER_SECRET
        else {
            problem(.twitterAuthenticatorUnconfigured)
            return
        }
        
        self.consumerCredentials = (key: key, secret: sec)
        
        allAccountsFor(provider: .twitter) {
        
            switch ($0) {
                case .accessNotGranted:
                    self.problem(.twitterAccountAccessNotGranted)
                case .noSystemAccounts:
                    self.problem(.noSystemTwitterAccount)
                case .accountStoreError(let message):
                    self.problem(.accountStoreFailure(message))
                case .success(let accounts):
                    self.handleMultiple(accounts: accounts)
            }
        }
    }

    
    private func handleMultiple(accounts: [ACAccount])
    {
        let usernames: [String] = accounts.map { $0.username }
        
        DispatchQueue.main.async {
            self.delegate?.twitterAccountSelection(withAccounts: usernames) { choice in
                
                guard let choice = choice else {
                    self.problem(.userCanceledAccountSelection)
                    return
                }
                
                for acc in accounts {
                    if acc.username == choice {
                        self.choosenAccount = acc
                        self.reverseAuthRequestToken()
                        return
                    }
                }
                
                self.problem(.accountStoreFailure("User selected non existing account username."))
            }
        }
    }

    
    private func responseSanityCheck(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Data?
    {
        guard error == nil else {
            let e = error! as NSError
            self.problem(.networkFailure(e.code, e.localizedDescription))
            return nil
        }
        guard let data = data, let response = response else {
            self.problem(.twitterFailure("No data and no error."))
            return nil
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            self.problem(.twitterFailure("No http status code received."))
            return nil
        }
        guard statusCode >= 200 && statusCode < 300 else {
            var emsg = "Twitter server returned status code: \(statusCode)"
            if let eadd = String(data: data, encoding: .utf8) {
                emsg += " Message: " + eadd
            }
            self.problem(.twitterFailure(emsg))
            return nil
        }

        return data
    }
    
    
    private func reverseAuthRequestToken()
    {
        let url = URL(string: "https://api.twitter.com/oauth/request_token")!
        let paras: [String: String] = ["x_auth_mode" : "reverse_auth"]
        
        var req = URLRequest(url: url)
        req.oAuthSign(method: "POST", urlFormParameters: paras, consumerCredentials: self.consumerCredentials)
        
        let task = URLSession(configuration: .ephemeral).dataTask(with: req) { (data, response, error) in
            
            guard let data = self.responseSanityCheck(data, response, error) else {
                return // error handled in responseSanityCheck
            }
            
            guard let token = String(data: data, encoding: .utf8) else {
                self.problem(.twitterFailure("Reverse auth response malformed. (not utf-8)"))
                return
            }
            self.requestCredentials(withReverseOAuthToken: token)
        }
        task.resume()
    }
    
    
    private func requestCredentials(withReverseOAuthToken reverseOAuthToken: String)
    {
        let url = URL(string: "https://api.twitter.com/oauth/access_token")
        
        let para = [
            "x_reverse_auth_parameters" : reverseOAuthToken,
            "x_reverse_auth_target" : consumerCredentials.key
        ]
        
        let req = SLRequest(forServiceType: SLServiceTypeTwitter, requestMethod: .POST, url: url, parameters: para)!
        req.account = self.choosenAccount
        req.perform { data, response, error in
            
            guard let data = self.responseSanityCheck(data, response, error) else {
                return // error handled in responseSanityCheck
            }
            
            guard data.count <= 3000 else {
                // We got a huge html page telling us our account was bannend :(
                self.problem(.twitterAccountBanned)
                return
            }
            guard let oauthSigString = String(data: data, encoding: .utf8) else {
                self.problem(.twitterFailure("Reverse auth signiture malformed. (not utf-8)"))
                return
            }
            
            let pc = self.split(queryString: oauthSigString)
            
            guard let key = pc["oauth_token"], let sec = pc["oauth_token_secret"] else {
                self.problem(.twitterFailure("Twitter credential query string does not contain the requested data."))
                return
            }
            
            self.verifyCredentials(userKey: key, userSecret: sec)
        }
    }
    

    private func verifyCredentials(userKey key: String, userSecret sec: String)
    {
        let baseURL = "https://api.twitter.com/1.1/account/verify_credentials.json"
        let query   = "include_email=true&include_entities=true&skip_status=false"
        
        var req = URLRequest(url: URL(string: "\(baseURL)?\(query)")!)
        req.oAuthSign(method: "GET",
                      consumerCredentials: self.consumerCredentials,
                      userCredentials: (key: key, secret: sec))
        
        
        let task = URLSession(configuration: .ephemeral).dataTask(with: req) { (data, response, error) in
            
            guard let data = self.responseSanityCheck(data, response, error) else {
                return // error handled in responseSanityCheck
            }
            
            guard let parsedJSON = self.toJSONObj(from: data) else {
                self.problem(.twitterFailure("JSON response not parsable."))
                return
            }
            
            guard
                let id     = parsedJSON["id_str"] as? String,
                let name   = parsedJSON["name"] as? String,
                let sname  = parsedJSON["screen_name"] as? String,
                let ava = parsedJSON["profile_image_url_https"] as? String,
                let avaURL = URL(string: ava.replacingOccurrences(of: "_normal.", with: "_400x400."))
            else {
                self.problem(.twitterFailure("Twitter verify credential query string does not contain the requested data."))
                return
            }
            
            let maybeEmail: String? = parsedJSON["email"] as? String
            
            let cred = Credentials(id: id, name: name, screenName: sname, key: key,
                                   secret: sec, email: maybeEmail, avatar: avaURL)
            
            DispatchQueue.main.async {
                self.delegate?.twitterAuthenticatorFinished(withCredentials: cred)
            }
            
        }
        task.resume()
    }
    
    
    private func problem(_ prob: Problem)
    {
        DispatchQueue.main.async {
            self.delegate?.twitterAuthenticatorFinished(withProblem: prob)
        }
    }
    

    private func split(queryString: String) -> [String: String]
    {
        var res: [String: String] = [:]
        let urlComponents = URLComponents(string: "?" + queryString)
        for qi in urlComponents?.queryItems ?? [] {
            res[qi.name] = qi.value
        }
        return res
    }
}

