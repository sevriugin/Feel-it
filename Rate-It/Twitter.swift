//
//  Twitter.swift
//  Rate-It
//
//  Created by Sergey Sevriugin on 17/02/2020.
//  Copyright © 2020 cuberto. All rights reserved.
//

import Foundation
import SwifteriOS

class Twitter {
    
    var swifter: Swifter?
    
    init() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) {
                if let key = dict["key"] as? String, let secret = dict["secret"] as? String {
                    swifter = Swifter(consumerKey: key, consumerSecret: secret)
                }
            }
        }
    }
}
