//
//  EMBluetoothService.swift
//  Business Services
//
//  Created by Martin Eberl on 07.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth

public class EMBluetoothServiceData: NSObject {
    let characteristicId:CBUUID!
    let properties:CBCharacteristicProperties!
    let permission:CBAttributePermissions!
    
    public init(characteristicId:CBUUID!, properties:CBCharacteristicProperties!, permission:CBAttributePermissions!) {
        self.characteristicId = characteristicId
        self.properties = properties
        self.permission = permission
    }
}
