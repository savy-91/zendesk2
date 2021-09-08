//
//  SwiftZendesk2Answer.swift
//  zendesk2
//
//  Created by Adrian Kohls on 12/08/21.
//
import Flutter
import Foundation
import ZendeskCoreSDK
import SupportProvidersSDK
import AnswerBotProvidersSDK

public class SwiftZendesk2Answer {
    
    private var channel: FlutterMethodChannel? = nil
    private var zendeskPlugin: SwiftZendesk2Plugin? = nil
    let answerBotProvider: AnswerBotProvider? = AnswerBot.instance?.provider
    
    init(channel: FlutterMethodChannel, flutterPlugin: SwiftZendesk2Plugin) {
        self.channel = channel
        self.zendeskPlugin = flutterPlugin
    }
    
    func initialize(_ arguments: Dictionary<String, Any>?) -> Void {
        var success = false
        let appId = (arguments?["appId"] ?? "") as? String
        let clientId = (arguments?["clientId"] ?? "") as? String
        let zendeskUrl = (arguments?["zendeskUrl"] ?? "") as? String
        
        let token = arguments?["token"] as? String
        let name = arguments?["name"] as? String
        let email = arguments?["email"] as? String
        
        if appId != nil && clientId != nil && zendeskUrl != nil {
            Zendesk.initialize(appId: appId!, clientId: clientId!, zendeskUrl: zendeskUrl!)
            
            let zendesk = Zendesk.instance
            
            let identity: Identity = token != nil ?
                Identity.createJwt(token: token!) :
                Identity.createAnonymous(name: name, email: email)
            
            Zendesk.instance?.setIdentity(identity)
            
            if zendesk != nil {
                Support.initialize(withZendesk: zendesk!)
                
                let support = Support.instance
                
                if support != nil {
                    AnswerBot.initialize(withZendesk: zendesk!, support: support!)
                    success = true
                }
            }
        }
        if !success {
            NSLog("Could not initialize Answer SDK")
        }
    }
    
    private func sendAnswerProviderModel(_ arguments: Dictionary<String, Any>?) -> Void {
        self.channel?.invokeMethod("sendAnswerProviderModel", arguments: arguments)
    }
    private func sendResolveArticleDeflection(_ arguments: Dictionary<String, Any>?) -> Void {
        self.channel?.invokeMethod("sendResolveArticleDeflection", arguments: arguments)
    }
    private func sendRejectArticleDeflection(_ arguments: Dictionary<String, Any>?) -> Void {
        self.channel?.invokeMethod("sendRejectArticleDeflection", arguments: arguments)
    }
    
    func deflectionQuery(_ arguments: Dictionary<String, Any>?) -> Void {
        let query: String = (arguments?["query"] ?? "") as! String
        
        answerBotProvider?.getDeflectionForQuery(query: query, callback: { result in
            switch result {
            case .success(let deflectionResponse):
                
                var dictionary = [String: Any]()
                
                let deflection = deflectionResponse.deflection
                let articles = deflectionResponse.deflectionArticles
                
                dictionary["interactionAccessToken"] = deflectionResponse.interactionAccessToken
                dictionary["deflectionId"] = deflection.deflectionID
                dictionary["description"] = deflectionResponse.description
                
                var mArticles = Array<Dictionary<String, Any>>()
                
                for article in articles {
                    var mArticle = [String: Any]()
                    
                    mArticle["deflectionArticleId"] = article.id
                    mArticle["brandId"] = article.brandId
                    mArticle["articleId"] = article.articleId
                    mArticle["body"] = article.body
                    mArticle["htmlURL"] = article.htmlURL
                    mArticle["labels"] = article.labelNames
                    mArticle["locale"] = article.locale
                    mArticle["score"] = article.score
                    mArticle["snippet"] = article.snippet
                    mArticle["title"] = article.title
                    mArticle["url"] = article.url
                    
                    mArticles.append(mArticle)
                }
                
                dictionary["articles"] = mArticles
                
                self.sendAnswerProviderModel(dictionary)
            case .failure(let error):
                NSLog(error.localizedDescription)
            }
        })
    }
    
    func resolveArticleDeflection(_ arguments: Dictionary<String, Any>?) -> Void {
        let deflectionId = arguments?["deflectionArticleId"] as! Int64
        let articleId = arguments?["articleId"] as! Int64
        let interactionAccessToken = arguments?["interactionAccessToken"] as! String
        
        answerBotProvider?.resolveWithArticle(deflectionId: deflectionId, articleId: articleId, interactionAccessToken: interactionAccessToken, callback: { result in
            var dictionary = [String: Any]()
            switch result {
            case .success(let response):
                dictionary["success"] = true
                NSLog("Success resolved article deflection: %@", response)
            case .failure(let error):
                dictionary["success"] = false
                NSLog("Error resolving article deflection: %@", error.localizedDescription)
            }
            self.sendResolveArticleDeflection(dictionary)
        })
    }
    
    func rejectArticleDeflection(_ arguments: Dictionary<String, Any>?) -> Void {
        let deflectionId = arguments?["deflectionArticleId"] as! Int64
        let articleId = arguments?["articleId"] as! Int64
        let interactionAccessToken = arguments?["interactionAccessToken"] as! String
        let reason = (arguments?["reason"] ?? "") as! String
        
        let mReason: RejectionReason = {
            switch reason {
            case "NOT_RELATED": return RejectionReason.notRelated
            case "RELATED_BUT_DIDNT_ANSWER": return RejectionReason.relatedButDidntAnswer
            default: return RejectionReason.unknown
            }
        }()
        
        answerBotProvider?.rejectWithArticle(deflectionId: deflectionId, articleId: articleId, interactionAccessToken: interactionAccessToken, reason: mReason, callback: { result in
            var dictionary = [String: Any]()
            switch result {
            case .success(let response):
                dictionary["success"] = true
                NSLog("Success rejecting article deflection: %@", response)
            case .failure(let error):
                dictionary["success"] = false
                NSLog("Error rejecting article deflection: %@", error.localizedDescription)
            }
            self.sendRejectArticleDeflection(dictionary)
        })
    }
}
