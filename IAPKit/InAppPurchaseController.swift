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
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didFinishRequestingProducts products:[SKProduct])
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didFailRequestingProductsWithError error:NSError)
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didFinishValidatingTransactionReceipt transaction:SKPaymentTransaction, withStatus status:Bool)
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didUpdatePaymentTransaction transaction:SKPaymentTransaction, withError error:NSError?)
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, restoreCompletedTransactionsFailedWithError error:NSError)
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didRemoveTransactions transactions:[SKPaymentTransaction])
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didUpdateDownloads downloads:[SKDownload])
    @objc optional func inAppPurchaseController(_ controller:InAppPurchaseController, didFailTransaction transaction:SKPaymentTransaction)
    @objc optional func inAppPurchaseControllerDidFinishRestoringTransactions(_ controller:InAppPurchaseController)
}

open class InAppPurchaseController : NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    open static let defaultController = InAppPurchaseController()
    
    fileprivate var productIdentifiers:Set<String>?
    fileprivate var purchasedProductIdentifiers:Set<String>
    fileprivate var productsRequest:SKProductsRequest
    fileprivate var completitionHandler:((_ success:Bool, _ products:[SKProduct]?, _ error:NSError?)->())?
    fileprivate var userDefaults:UserDefaults = UserDefaults.standard
    
    open var inAppProducts:[SKProduct]?
    open var didFinishRequestingProducts:Bool?
    open var delegate:InAppPurchaseControllerDelegate?
    open var userDefaultsSuit:String? = nil  {
        didSet {
            guard let userDefaults = UserDefaults(suiteName: userDefaultsSuit) else { return }
            self.userDefaults = userDefaults
        }
    }

    
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
    open func setupController(_ productIdentifiers:Set<String>) {
        self.registerAsTransactionObserver(self)
        self.productIdentifiers = productIdentifiers
        self.purchasedProductIdentifiers = self.getPurchasedProducts(productIdentifiers)
        self.productsRequest = self.setupProductsRequest(productIdentifiers, delegate: self)
    }
    
    open func requestProducts() {
        self.productsRequest.start()
        self.didFinishRequestingProducts = false
    }
    
    open func purchaseProduct(_ product:SKProduct) {
        let productPayment = SKPayment(product: product)
        SKPaymentQueue.default().add(productPayment)
    }
    
    open func restoreCompletedTransactions() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    open func isProductPurchased(_ productIdentifier:String) -> Bool {
//        #if DEBUG
//            return true
//        #endif
        return self.purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    // MARK: - Setup Methods
    fileprivate func registerAsTransactionObserver(_ transactionObserver:SKPaymentTransactionObserver) {
        SKPaymentQueue.default().add(transactionObserver)
    }
    
    fileprivate func getPurchasedProducts(_ productIdentifiers:Set<String>) -> Set<String> {
        var purchasedProductIdentifiers:Set<String> = []
        
        for productIdentifier in productIdentifiers {
            if (userDefaults.bool(forKey: productIdentifier)) {
                purchasedProductIdentifiers.insert(productIdentifier)
            }
        }
        return purchasedProductIdentifiers
    }
    
    fileprivate func setupProductsRequest(_ productIdentifiers:Set<String>, delegate:SKProductsRequestDelegate) -> SKProductsRequest  {
        let productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = delegate
        
        return productsRequest
    }
    
    // MARK: - Receipt Validation Return
    fileprivate func validatedReceiptForTransaction(_ paymentTransaction:SKPaymentTransaction, validated:Bool) {
        if (validated == true) {
            userDefaults.set(true, forKey: paymentTransaction.payment.productIdentifier)
            self.purchasedProductIdentifiers.insert(paymentTransaction.payment.productIdentifier)
        }
        self.delegate?.inAppPurchaseController?(self, didFinishValidatingTransactionReceipt: paymentTransaction, withStatus: validated)
        SKPaymentQueue.default().finishTransaction(paymentTransaction)
    }
    
    // MARK: - SKProductsRequestDelegate
    open func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        request.cancel()
        self.inAppProducts = response.products
        self.didFinishRequestingProducts = true
        self.delegate?.inAppPurchaseController?(self, didFinishRequestingProducts: response.products)
    }
    
    open func request(_ request: SKRequest, didFailWithError error: Error) {
        request.cancel()
        self.delegate?.inAppPurchaseController?(self, didFailRequestingProductsWithError: error as NSError)
    }
    
    // MARK: - SKPaymentTransactionObserver
    open func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for paymentTransaction in transactions {
            self.delegate?.inAppPurchaseController?(self, didUpdatePaymentTransaction: paymentTransaction, withError: paymentTransaction.error as NSError?)
            
            switch paymentTransaction.transactionState {
            case .purchasing:
                break
            case .purchased:
                validatedReceiptForTransaction(paymentTransaction, validated: true)
                break
            case .restored:
                validatedReceiptForTransaction(paymentTransaction, validated: true)
                break
            case .deferred:
                break
            case .failed:
                self.delegate?.inAppPurchaseController?(self, didFailTransaction: paymentTransaction)
                SKPaymentQueue.default().finishTransaction(paymentTransaction)
                break
            }
        }
    }
    
    open func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        self.delegate?.inAppPurchaseControllerDidFinishRestoringTransactions?(self)
    }
    
    open func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        self.delegate?.inAppPurchaseController?(self, restoreCompletedTransactionsFailedWithError: error as NSError)
    }
    
    open func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        self.delegate?.inAppPurchaseController?(self, didRemoveTransactions: transactions)
    }
    
    open func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        self.delegate?.inAppPurchaseController?(self, didUpdateDownloads: downloads)
    }
    
}
