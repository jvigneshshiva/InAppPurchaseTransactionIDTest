//
//  ViewController.swift
//  InAppPurchaseTransactionTest
//
//  Created by Vignesh on 28/07/16.
//  Copyright © 2016 Vignesh. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var storeKitManager : StoreKitManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        storeKitManager = StoreKitManager.sharedInstance

        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func recipetValidationButtonClicked() {
        storeKitManager.localReceiptValidation{(products) in
            
            dispatch_async(dispatch_get_main_queue(),{
                UIAlertView.init(title: "Transaction IDs", message: "\(products)", delegate: nil, cancelButtonTitle: "OK").show()
            })

            }
    }

}

