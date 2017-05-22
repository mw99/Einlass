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

import UIKit
import Einlass

class SNSAuthController: UIViewController, FacebookAuthenticatorDelegate, TwitterAuthenticatorDelegate
{
    @IBOutlet weak var resultText: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var avatarImageView: UIImageView!
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////
    /// Authenticate user with TWITTER
    
    @IBAction func twitterTabbed(_ sender: Any)
    {
        activityIndicator.startAnimating()
        
        let twAuthenticator = TwitterAuthenticator()
        twAuthenticator.delegate = self
        
        twAuthenticator.perform()
    }
    
    func twitterAuthenticatorFinished(withCredentials credentials: TwitterAuthenticator.Credentials)
    {
        activityIndicator.stopAnimating()
        
        let msg: [String] = [
            "Twitter reverse authentication successful! Credentials:",
            "TWID: \(credentials.id)",
            "Name: \(credentials.name)",
            "Screen Name: \(credentials.screenName)",
            "Key: \(credentials.key)",
            "Secret: \(credentials.secret)",
            "EMail: \(credentials.email ?? "nil")",
            "Avatar URL: \(credentials.avatar)"
        ]
        
        avatarImageView.load(fromURL: credentials.avatar)
        
        resultText.text = msg.joined(separator: "\n\n")
        print(resultText.text)
    }
    
    func twitterAuthenticatorFinished(withProblem problem: TwitterAuthenticator.Problem)
    {
        activityIndicator.stopAnimating()
        
        switch problem {
            
        case .noSystemTwitterAccount:
            resultText.text = "No Twitter system account registerd. Go to iOS settings to set some up..."
            
        case .twitterAccountAccessNotGranted:
            resultText.text = "Permission to access Twitter system accounts was not granted. The access popup is only shown once to the user."
            
        case .userCanceledAccountSelection:
            resultText.text = "Account selection canceled by the user."
            
        case .twitterAccountBanned:
            resultText.text = "This twitter account has been banned by Twitter. Visit the twitter page to reactivate it. This happens often with testaccount that have not been verified with a telephone number."
            
        case .twitterAuthenticatorUnconfigured:
            resultText.text = "Goto https://apps.twitter.com/, register a new app, then set TwitterAuthenticator.consumerCredentialProvider accordingly in your AppDelegate."
            
        case .networkFailure(let code, let debugMessage):
            // general error for network problems. code = NSURLErrorDomain codes
            resultText.text = "Network trouble :(\nCode: \(code), Error Message: \(debugMessage)"
            
        case .twitterFailure(let debugMessage):
            // general error for unrecoverable twitter server communication failure
            resultText.text = "Trouble with Twitter :(\nError Message: \(debugMessage)"
            
            
        case .accountStoreFailure(let debugMessage):
            // general error for unrecoverable ios account store failure
            resultText.text = "Trouble while accessing Twitter accounts  :(\nError Message: \(debugMessage)"
        }
    }
    
    func twitterAccountSelection(withAccounts accounts: [String], choice: @escaping (String?)->())
    {
        // Let the user choose one out of multiple user accounts
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for acc in accounts {
            alert.addAction(UIAlertAction(title: acc, style: .default, handler: { _ in choice(acc) } ))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in choice(nil) } ))
        
        self.present(alert, animated: true)
    }
    
    
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////
    /// Authenticate user with FACEBOOK
    
    @IBAction func facebookTabbed(_ sender: Any)
    {
        activityIndicator.startAnimating()
     
        let fbAuthenticator = FacebookAuthenticator()
        fbAuthenticator.delegate = self
        
        // About Facebook account access permissions:
        // Documentation: https://developers.facebook.com/docs/facebook-login/permissions
        // Default:       "user_birthday", "user_location", "user_friends", "email", "public_profile"
        fbAuthenticator.permissions = ["public_profile", "email"]
        // Audience options: .onlyMe, .friends, .everyone  (default: .onlyMe)
        fbAuthenticator.audience = .onlyMe
        
        fbAuthenticator.perform()
    }
    
    func facebookAuthenticatorFinished(withCredentials credentials: FacebookAuthenticator.Credentials)
    {
        activityIndicator.stopAnimating()
       
        let msg: [String] = [
            "Facebook reverse authentication successful! Credentials:",
            "FBID: \(credentials.id)",
            "Name: \(credentials.name)",
            "Token: \(credentials.token)",
            "EMail: \(credentials.email ?? "nil")",
            "Avatar URL: \(credentials.avatar)"
        ]
        
        avatarImageView.load(fromURL: credentials.avatar)
        
        resultText.text = msg.joined(separator: "\n\n")
        print(resultText.text)
    }
    
    func facebookAuthenticatorFinished(withProblem problem: FacebookAuthenticator.Problem)
    {
        activityIndicator.stopAnimating()
       
        switch problem {
            
        case .noSystemFacebookAccount:
            resultText.text = "No Facebook system account registerd. Go to iOS settings to set some up..."
            
        case .facebookAccountAccessNotGranted:
            resultText.text = "Permission to access Facebook system account was not granted."
            
        case .userCanceledAccountSelection:
            resultText.text = "Account selection canceled by the user."
            
        case .systemAccountReloginNeeded:
            resultText.text = "The Facebook system account is not valid anymore. Open iOS settings to relogin. Happens if the user changes his/her password or gets banned on facebook."
            
        case .facebookAuthenticatorUnconfigured:
            resultText.text = "Goto https://developers.facebook.com/docs/apps/register, register a new app with the corrent bundle identifier, then set FacebookAuthenticator.consumerCredentialProvider accordingly in your AppDelegate."
            
        case .networkFailure(let code, let debugMessage):
            // general error for network problems. code = NSURLErrorDomain codes
             resultText.text = "Network trouble :(\nCode: \(code), Error Message: \(debugMessage)"
            
        case .facebookFailure(let debugMessage):
            // general error for unrecoverable Facebook server communication failure
            resultText.text = "Trouble with Facebook :(\nError Message: \(debugMessage)"
            
        case .accountStoreFailure(let debugMessage):
            // general error for unrecoverable ios account store failure
            resultText.text = "Trouble while accessing facebook accounts  :(\nError Message: \(debugMessage)"
        }
    }
    
    func facebookAccountConfirmation(withAccount account: String, proceed: @escaping (Bool)->())
    {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: account, style: .default, handler: { _ in proceed(true) } ))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in proceed(false) } ))
        
        self.present(alert, animated: true)
    }
}



extension UIImageView
{
    func load(fromURL url: URL)
    {
        let setImg: (Data?, URLResponse?, Error?) -> () = { (data, _, _) in
            guard let data = data else { return }
            DispatchQueue.main.async { self.image = UIImage(data: data) }
        }
        URLSession.shared.dataTask(with: url, completionHandler: setImg).resume()
    }
}


