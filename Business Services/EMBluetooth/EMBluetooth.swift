//
//  EMBluetooth.swift
//  Business Services
//
//  Created by Martin Eberl on 07.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth

public class EMBluetooth: NSObject {
    
    //MARK: - Public Methods

    public static func advertiser(serviceId:CBUUID?) -> EMBluetoothServiceAdvertiser! {
        return EMBluetoothServiceAdvertiser(serviceId: serviceId)
    }
    
    public static func listener() -> EMBluetoothServiceListener! {
        return EMBluetoothServiceListener()
    }
}
