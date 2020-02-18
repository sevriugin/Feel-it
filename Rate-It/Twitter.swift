//
//  Twitter.swift
//  Rate-It
//
//  Created by Sergey Sevriugin on 17/02/2020.
//  Copyright © 2020 Sergei Sevriugin. All rights reserved.
//

import Foundation
import SwifteriOS
import CoreML
import SwiftyJSON

@available(iOS 12.0, *)
class Twitter {
    
    var swifter: Swifter?
    let model = TwitterSentimentalAnalysis()
    var score: Float?
    var total: Int?
    
    init() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) {
                if let key = dict["key"] as? String, let secret = dict["secret"] as? String {
                    swifter = Swifter(consumerKey: key, consumerSecret: secret)
                }
            }
        }
    }
    
    func score(q: String) -> Void {
        score = nil
        total = nil
        
        swifter?.searchTweet(using: q, lang: "en", count: 100, tweetMode: .extended, success: { (results, metadata) in
            
            var texts = [TwitterSentimentalAnalysisInput]()
            var count = 0
            
            if let metaCount = metadata["count"].integer {
                
                for i in 0..<metaCount {
                    
                    if let text = results[i]["full_text"].string {
                        texts.append(TwitterSentimentalAnalysisInput(text: text))
                        count += 1
                    }
                    
                }
            }
            
            print("We have \(count) tweets for prediction")
            
            do {
                let predictions = try self.model.predictions(inputs: texts)
                
                var qScore: Float = 0.0
                
                for prediction in predictions {
                    
                    
                    if prediction.label == "Pos" {
                        qScore += 1.0
                    } else if prediction.label == "Neg" {
                        qScore -= 1.0
                    }
                    
                }
                
                if count > 0 {
                    self.score = ( Float(count) + qScore ) / ( 2.0 * Float(count) )
                    self.total = count
                    
                    print("Score is \(self.score!)")
                    print("Total is \(self.total!)")
                }
                
            } catch  {
                print(error)
            }
            
            
        }, failure: { error in
            print(error)
        })
    }
}
