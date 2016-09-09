//
//  Definitions.swift
//  Business Services
//
//  Created by Martin Eberl on 01.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth

let TRANSFER_SERVICE_UUID = "E20B39F4-73A5-5CD6-A22D-17D1AD777771"
let TRANSFER_READ_CHARACTERISTIC_UUID = "08690F7E-DBE5-4E7E-8E57-72F6F77777D4"
let TRANSFER_WRITE_CHARACTERISTIC_UUID = "08690F7E-DBE5-4E7E-8E57-72F6F77777D5"
let NOTIFY_MTU = 20

let transferServiceUUID = CBUUID(string: TRANSFER_SERVICE_UUID)
let transferReadCharacteristicUUID = CBUUID(string: TRANSFER_READ_CHARACTERISTIC_UUID)
let transferWriteCharacteristicUUID = CBUUID(string: TRANSFER_WRITE_CHARACTERISTIC_UUID)