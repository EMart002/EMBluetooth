//
//  ViewControllerClient2.swift
//  Business Services
//
//  Created by Martin Eberl on 09.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewControllerClient2: UIViewController {
    private var listener:EMBluetoothServiceListener? = nil
    private var service:EMBluetoothService? = nil
    @IBOutlet weak var label:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        listener = EMBluetooth.listener()
        
        service = listener?.listen(transferServiceUUID)
        
        service!.receivedData = {[weak self] (request) in
            return CBATTError.Success
        }
        
        service?.centralSubscriped = {[weak self] (central) in
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction internal func start(sender:UIButton) {
        listener?.scan = !(listener?.scan)!
        
        if !(listener?.scan)! {
            sender.setTitle("Listen", forState: .Normal)
        } else {
            sender.setTitle("Stop", forState: .Normal)
        }
    }
}
