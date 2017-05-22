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

struct Const: FacebookConsumerCredentialProvider, TwitterConsumerCredentialProvider
{
    static let FACEBOOK_APP_ID = <YOUR_FACEBOOK_APP_ID>
    
    static let TWITTER_CONSUMER_KEY    = <YOUR_TWITTER_CONSUMER_KEY>
    static let TWITTER_CONSUMER_SECRET = <YOUR_TWITTER_CONSUMER_SECRET>
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        FacebookAuthenticator.consumerCredentialProvider = Const.self
        TwitterAuthenticator.consumerCredentialProvider  = Const.self
        
        return true
    }
}

