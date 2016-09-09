//
//  ViewControllerServer2.swift
//  Business Services
//
//  Created by Martin Eberl on 08.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewControllerServer2: UIViewController {
    private var advertiser:EMBluetoothServiceAdvertiser? = nil
    private var readService:EMBluetoothService? = nil
    private var writeService:EMBluetoothService? = nil
    @IBOutlet internal var textView:UITextView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        advertiser = EMBluetooth.advertiser(transferServiceUUID)
        
        advertiser?.localName = "Hello World"
        
        writeService = advertiser?.addAdvertising(
            transferReadCharacteristicUUID,
            properties:.Notify,
            permission:.Readable)
        
        writeService!.receivedData = {[weak self] (request) in
            return CBATTError.Success
        }
        
        writeService?.centralSubscriped = {[weak self] (central) in
            
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        advertiser?.stopAdvertising()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction internal func start(sender:UIButton) {
        advertiser?.advertise = !(advertiser?.advertise)!
        
        if !(advertiser?.advertise)! {
            sender.setTitle("Start", forState: .Normal)
        } else {
            sender.setTitle("Stop", forState: .Normal)
        }
    }
    
    @IBAction internal func send(sender:UIButton) {
        writeService?.send(textView!.text.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
}
