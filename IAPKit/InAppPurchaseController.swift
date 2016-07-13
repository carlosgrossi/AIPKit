//
//  InAppPurchaseController.swift
//  CS:GO Nexus
//
//  Created by Carlos Grossi on 15/3/16.
//  Copyright © 2016 Carlos Grossi. All rights reserved.
//

import Foundation
import StoreKit
import ExtensionKit

@objc public protocol InAppPurchaseControllerDelegate {
    optional func inAppPurchaseController(controller:InAppPurchaseController, didFinishRequestingProducts products:[SKProduct])
    optional func inAppPurchaseController(controller:InAppPurchaseController, didFailRequestingProductsWithError error:NSError)
    optional func inAppPurchaseController(controller:InAppPurchaseController, didFinishValidatingTransactionReceipt transaction:SKPaymentTransaction, withStatus status:Bool)
    optional func inAppPurchaseController(controller:InAppPurchaseController, didUpdatePaymentTransaction transaction:SKPaymentTransaction, withError error:NSError?)
    optional func inAppPurchaseController(controller:InAppPurchaseController, restoreCompletedTransactionsFailedWithError error:NSError)
    optional func inAppPurchaseController(controller:InAppPurchaseController, didRemoveTransactions transactions:[SKPaymentTransaction])
    optional func inAppPurchaseController(controller:InAppPurchaseController, didUpdateDownloads downloads:[SKDownload])
    optional func inAppPurchaseController(controller:InAppPurchaseController, didFailTransaction transaction:SKPaymentTransaction)
    optional func inAppPurchaseControllerDidFinishRestoringTransactions(controller:InAppPurchaseController)
}

public class InAppPurchaseController : NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    public static let defaultController = InAppPurchaseController()
    
    private var productIdentifiers:Set<String>?
    private var purchasedProductIdentifiers:Set<String>
    private var productsRequest:SKProductsRequest
    private var completitionHandler:((success:Bool, products:[SKProduct]?, error:NSError?)->())?
    
    public var inAppProducts:[SKProduct]?
    public var didFinishRequestingProducts:Bool?
    public var delegate:InAppPurchaseControllerDelegate?

    
    // MARK - Initializers
    override public init() {
        self.purchasedProductIdentifiers = []
        self.productsRequest = SKProductsRequest()
    }
    
    convenience public init(productIdentifiers:Set<String>) {
        self.init()
        self.setupController(productIdentifiers)
    }
    
    // MARK: - Purchase & Restore
    public func setupController(productIdentifiers:Set<String>) {
        self.registerAsTransactionObserver(self)
        self.productIdentifiers = productIdentifiers
        self.purchasedProductIdentifiers = self.getPurchasedProducts(productIdentifiers)
        self.productsRequest = self.setupProductsRequest(productIdentifiers, delegate: self)
    }
    
    public func requestProducts() {
        self.productsRequest.start()
        self.didFinishRequestingProducts = false
    }
    
    public func purchaseProduct(product:SKProduct) {
        let productPayment = SKPayment(product: product)
        SKPaymentQueue.defaultQueue().addPayment(productPayment)
    }
    
    public func restoreCompletedTransactions() {
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    public func isProductPurchased(productIdentifier:String) -> Bool {
        return self.purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    // MARK: - Setup Methods
    private func registerAsTransactionObserver(transactionObserver:SKPaymentTransactionObserver) {
        SKPaymentQueue.defaultQueue().addTransactionObserver(transactionObserver)
    }
    
    private func getPurchasedProducts(productIdentifiers:Set<String>) -> Set<String> {
        var purchasedProductIdentifiers:Set<String> = []
        
        for productIdentifier in productIdentifiers {
            if (NSUserDefaults.standardUserDefaults().boolForKey(productIdentifier)) {
                purchasedProductIdentifiers.insert(productIdentifier)
            }
        }
        return purchasedProductIdentifiers
    }
    
    private func setupProductsRequest(productIdentifiers:Set<String>, delegate:SKProductsRequestDelegate) -> SKProductsRequest  {
        let productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = delegate
        
        return productsRequest
    }
    
    // MARK: - Receipt Validation Return
    private func validatedReceiptForTransaction(paymentTransaction:SKPaymentTransaction, validated:Bool) {
        if (validated == true) {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: paymentTransaction.payment.productIdentifier)
            self.purchasedProductIdentifiers.insert(paymentTransaction.payment.productIdentifier)
        }
        self.delegate?.inAppPurchaseController?(self, didFinishValidatingTransactionReceipt: paymentTransaction, withStatus: validated)
        SKPaymentQueue.defaultQueue().finishTransaction(paymentTransaction)
    }
    
    // MARK: - SKProductsRequestDelegate
    public func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        request.cancel()
        self.inAppProducts = response.products
        self.didFinishRequestingProducts = true
        self.delegate?.inAppPurchaseController?(self, didFinishRequestingProducts: response.products)
    }
    
    public func request(request: SKRequest, didFailWithError error: NSError) {
        request.cancel()
        self.delegate?.inAppPurchaseController?(self, didFailRequestingProductsWithError: error)
    }
    
    // MARK: - SKPaymentTransactionObserver
    public func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for paymentTransaction in transactions {
            self.delegate?.inAppPurchaseController?(self, didUpdatePaymentTransaction: paymentTransaction, withError: paymentTransaction.error)
            
            switch paymentTransaction.transactionState {
            case .Purchasing:
                break
            case .Purchased:
                paymentTransaction.validateReceipt(self.validatedReceiptForTransaction)
                break
            case .Restored:
                paymentTransaction.validateReceipt(self.validatedReceiptForTransaction)
                break
            case .Deferred:
                break
            case .Failed:
                self.delegate?.inAppPurchaseController?(self, didFailTransaction: paymentTransaction)
                SKPaymentQueue.defaultQueue().finishTransaction(paymentTransaction)
                break
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        self.delegate?.inAppPurchaseControllerDidFinishRestoringTransactions?(self)
    }
    
    public func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
        self.delegate?.inAppPurchaseController?(self, restoreCompletedTransactionsFailedWithError: error)
    }
    
    public func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        self.delegate?.inAppPurchaseController?(self, didRemoveTransactions: transactions)
    }
    
    public func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        self.delegate?.inAppPurchaseController?(self, didUpdateDownloads: downloads)
    }
    
}
