//
//  StoreKitManager.swift
//  InAppPurchaseTestSwift
//
//  Created by Vignesh on 29/12/15.
//  Copyright © 2015 Vignesh. All rights reserved.
//


import StoreKit

/// Notification that is generated when a product is purchased.
public let StoreKitManagerProductPurchasedNotification = "StoreKitManagerProductPurchasedNotification"

public let StoreKitManagerProductRestoredNotification = "StoreKitManagerProductRestoredNotification"

public let StoreKitManagerProductPurchaseFailureNotification = "StoreKitManagerProductPurchaseFailureNotification"

public typealias CompletionHandler = (transactions: [String]?) -> ()



/// Product identifiers are unique strings registered on the app store.
public typealias ProductIdentifier = String

/// Completion handler called when products are fetched.
public typealias RequestProductsCompletionHandler = (success: Bool, products: [SKProduct]) -> ()


/// A Helper class for In-App-Purchases, it can fetch products, tell you if a product has been purchased,
/// purchase products, and restore purchases.  Uses NSUserDefaults to cache if a product has been purchased.
public class StoreKitManager : NSObject  {
    
    public static let sharedInstance = StoreKitManager()
    
    
    /// MARK: - Private Properties
    
    // Used to keep track of the possible products and which ones have been purchased.
    private var productIdentifiers = Set<ProductIdentifier>()
    private var purchasedProductIdentifiers = Set<ProductIdentifier>()
    
    // Used by SKProductsRequestDelegate
    private var productsRequest: SKProductsRequest?
    private var completionHandler: RequestProductsCompletionHandler?
    
    /// MARK: - User facing API
    
    override init() {
        super.init()
        SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    }
    
    /// Gets the list of SKProducts from the Apple server calls the handler with the list of products.
    public func requestProducts(productIdentifiers: Set<ProductIdentifier>, WithCompletionHandler handler: RequestProductsCompletionHandler) {
        completionHandler = handler
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    /// Initiates purchase of a product.
    public func purchaseProduct(product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.defaultQueue().addPayment(payment)
    }
    
    /// Given the product identifier, returns true if that product has been purchased.
    public func isProductPurchased(productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    /// If the state of whether purchases have been made is lost  (e.g. the
    /// user deletes and reinstalls the app) this will recover the purchases.
    public func restoreCompletedTransactions() {
        let refreshRequest = SKReceiptRefreshRequest()
        refreshRequest.delegate = self
        refreshRequest.start()
    }
    
    public func requestDidFinish(request: SKRequest)
    {
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
}

// This extension is used to get a list of products, their titles, descriptions,
// and prices from the Apple server.

extension StoreKitManager: SKProductsRequestDelegate {
    public func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        print("Loaded list of products...")
        let products = response.products
        completionHandler?(success: true, products: products)
        clearRequest()
        
        // debug printing
        for p in products {
            print("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)")
        }
    }
    
    public func request(request: SKRequest, didFailWithError error: NSError) {
        print("Failed to load list of products.")
        print("Error: \(error)")
        NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductPurchaseFailureNotification, object: nil)
        clearRequest()
    }
    
    private func clearRequest() {
        productsRequest = nil
        completionHandler = nil
    }
}


extension StoreKitManager: SKPaymentTransactionObserver {
    /// This is a function called by the payment queue, not to be called directly.
    /// For each transaction act accordingly, save in the purchased cache, issue notifications,
    /// mark the transaction as complete.
    public func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print("Transactions \(transactions)")
        for transaction in transactions {
            print("Transaction : \(transaction)")
            
            switch (transaction.transactionState) {
            case .Purchased:
                completeTransaction(transaction)
                break
            case .Failed:
                failedTransaction(transaction)
                break
            case .Restored:
                restoreTransaction(transaction)
                break
            case .Deferred:
                break
            case .Purchasing:
                break
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue)
    {
        if(queue.transactions.count == 0)
        {
            NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductPurchaseFailureNotification, object: nil)
        }
    }
    
    private func completeTransaction(transaction: SKPaymentTransaction) {
        print("completeTransaction...")
        provideContentForProductIdentifier(transaction.payment.productIdentifier)
        NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductPurchasedNotification, object: transaction)
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    
    private func restoreTransaction(transaction: SKPaymentTransaction) {
        var productIdentifier: String!
        if ((transaction.originalTransaction) != nil) {
            productIdentifier = transaction.originalTransaction!.payment.productIdentifier;
        }
        else {
            productIdentifier = transaction.payment.productIdentifier;
        }
        if ((productIdentifier) != nil) {
            print("restoreTransaction... \(productIdentifier)")
            provideContentForProductIdentifier(productIdentifier)
            NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductRestoredNotification, object: transaction)
            SKPaymentQueue.defaultQueue().finishTransaction(transaction)
        }
    }
    
    public func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError)
    {
        NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductPurchaseFailureNotification, object: nil)
    }
    
    
    
    // Helper: Saves the fact that the product has been purchased and posts a notification.
    private func provideContentForProductIdentifier(productIdentifier: String) {
        purchasedProductIdentifiers.insert(productIdentifier)
    }
    
    private func removeContentForProductIdentifier(productIdentifier: String) {
        if(purchasedProductIdentifiers.contains(productIdentifier))
        {
            purchasedProductIdentifiers.remove(productIdentifier)
        }
    }
    
    public func receiptString()-> String
    {
        var receiptString = ""
        
        if let receiptPath = NSBundle.mainBundle().appStoreReceiptURL?.path where
            NSFileManager.defaultManager().fileExistsAtPath(receiptPath), let receiptData = NSData(contentsOfURL:NSBundle.mainBundle().appStoreReceiptURL!) {
                receiptString = receiptData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        }
        return receiptString
    }
    
    public func expirationDateFromResponse(jsonResponse: NSDictionary) -> NSDate? {
        if let receiptInfo: NSArray = jsonResponse["latest_receipt_info"] as? NSArray {
            let lastReceipt = receiptInfo.lastObject as! NSDictionary
            let formatter = NSDateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
            let expirationDate: NSDate =
            formatter.dateFromString(lastReceipt["expires_date"] as! String) as NSDate!
            print("Expiry Date : \(expirationDate)")
            return expirationDate
        } else {
            return nil
        }
    }
    
    
    public func updateIAPExpirationDate(expirationDate : NSDate)
    {
        let todayDate : NSDate = NSDate()
        if(todayDate.timeIntervalSince1970 < expirationDate.timeIntervalSince1970)
        {
            // Subscription Active
        }
        else
        {
            // Subscription Inactive
        }
    }
    
    private func failedTransaction(transaction: SKPaymentTransaction) {
        print("failedTransaction...")
        NSNotificationCenter.defaultCenter().postNotificationName(StoreKitManagerProductPurchaseFailureNotification, object: transaction)
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    
    public func localReceiptValidation(completion : CompletionHandler)  {
        
        if let receiptPath = NSBundle.mainBundle().appStoreReceiptURL?.path where
            NSFileManager.defaultManager().fileExistsAtPath(receiptPath), let receiptData = NSData(contentsOfURL:NSBundle.mainBundle().appStoreReceiptURL!) {
            let receiptString = receiptData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
            NSUserDefaults.standardUserDefaults().setObject(receiptString, forKey: "receiptString")
            let receiptDictionary = ["receipt-data" : receiptString,"password" : "d83dd06e9cf24605a53c3e5786b74613"]
            let requestData = try! NSJSONSerialization.dataWithJSONObject(receiptDictionary, options: NSJSONWritingOptions(rawValue: 0)) as NSData!
            let storeURL = NSURL(string:
                "https://buy.itunes.apple.com/verifyReceipt")!
            let storeRequest = NSMutableURLRequest(URL: storeURL)
            storeRequest.HTTPMethod = "POST"
            storeRequest.HTTPBody = requestData
            let session = NSURLSession(configuration:
                NSURLSessionConfiguration.defaultSessionConfiguration())
            session.dataTaskWithRequest(storeRequest, completionHandler: { (data: NSData?, response: NSURLResponse?,connection: NSError?) -> Void in
                print("Call Successfull")
                if let jsonResponse: NSDictionary = try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as?NSDictionary {
                    print(jsonResponse)
                    var transactionIds : [String] = []
                    if let arrayOfReceipts : [[String : AnyObject]] = jsonResponse["latest_receipt_info"] as! [[String : AnyObject]] {
                    for receiptInfo in arrayOfReceipts {
                        let transactionId = receiptInfo["transaction_id"] as! String
                        transactionIds.append(transactionId)
                    }
                    completion(transactions: transactionIds)
                    }else{
                        completion(transactions : ["\(jsonResponse)"])
                    }
                }
            }).resume()
        }
    }

}