//
//  EMBluetoothAdvertisment.swift
//  Business Services
//
//  Created by Martin Eberl on 07.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth
import UIKit

private class EMBluetoothDataSend: NSObject {
    private(set) var data:NSData!
    private(set) var respond:EMBluetoothServiceRespond!
    private(set) var service:EMBluetoothService!
    private(set) var characteristic:CBMutableCharacteristic!
    
    var sendDataIndex:Int = 0
    var timestamp:NSTimeInterval = 0
    
    init(data:NSData!, characteristic:CBMutableCharacteristic!, respond:EMBluetoothServiceRespond!) {
        self.data = data
        self.characteristic = characteristic
        self.respond = respond
    }
}

public class EMBluetoothServiceAdvertiser: NSObject, CBPeripheralManagerDelegate, EMBluetoothServiceDelegate {
    private var transferService:CBMutableService!
    private var peripheralManager:CBPeripheralManager!
    private var serviceAdded:Bool! = false
    private var services:[EMBluetoothService]?
    private var sendList:[EMBluetoothDataSend]!
    private var internalActive:Bool = false
    
    private(set) var serviceId:CBUUID!
    
    public var localName:String?
    
    public var centralRequests:((CBATTRequest)->CBATTError)?
    public var centralResponds:((CBATTRequest)->CBATTError)?
    
    public var advertise:Bool! {
        set {
            guard peripheralManager.state == .PoweredOn else {
                return
            }
            
            internalActive = newValue
            
            if internalActive {
                self.peripheralManager.addService(transferService)
                peripheralManager.startAdvertising(advertismentParameters(serviceId))
            }
            else {
                self.peripheralManager.removeService(transferService)
                peripheralManager.stopAdvertising()
            }
        }
        get {
            return internalActive
        }
    }
    
    public init(serviceId:CBUUID!) {
        super.init()
        
        self.serviceId = serviceId
        self.transferService = CBMutableService(
            type: serviceId,
            primary: true
        )
        
        sendList = [EMBluetoothDataSend]()
        services = [EMBluetoothService]()
        
        peripheralManager = CBPeripheralManager(delegate:self, queue: nil)
    }
    
    deinit {
        advertise = false
    }
    
    //MARK: - Public Methods
    
    public func addAdvertising(characteristicId:CBUUID!, properties:CBCharacteristicProperties!, permission:CBAttributePermissions!) -> EMBluetoothService {
        
        let characteristic = CBMutableCharacteristic(
            type: characteristicId,
            properties: properties,
            value: nil,
            permissions: permission)
        
        var characterists = transferService.characteristics
        if characterists == nil {
            characterists = [CBMutableCharacteristic]()
        }
        characterists?.append(characteristic)
        
        
        transferService.characteristics = characterists
        
        var descriptors = characteristic.descriptors
        if descriptors == nil {
            descriptors = [CBMutableDescriptor]()
        }
        let discriptor = CBMutableDescriptor(
            type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
            value: "Test"
        )
        descriptors?.append(discriptor)
        characteristic.descriptors = descriptors
        
        if self.serviceAdded! {
            return findOrCreateService(characteristic)
        }
        
        self.serviceAdded = true
        return findOrCreateService(characteristic)
    }
    
    public func removeAdvertising(service:EMBluetoothService) {
        
        let service = findService(service.characteristic.UUID)
        
        transferService.characteristics?.removeAtIndex((transferService.characteristics?.indexOf(service.characteristic))!)
        services?.removeAtIndex((services?.indexOf(service))!)
        
        if services?.count == 0 {
            advertise = false
        }
    }
    
    public func stopAdvertising() {
        
        for service in services! {
            removeAdvertising(service)
        }
        
        advertise = false
    }
    
    //MARK:- Private Methods
    private func advertismentParameters(serviceId:CBUUID!) -> [String:AnyObject]? {
        guard serviceId != nil else {
            return nil
        }
        
        var dict = [String:AnyObject]()
        dict[CBAdvertisementDataServiceUUIDsKey] = [serviceId]
        
        if localName != nil {
            dict[CBAdvertisementDataLocalNameKey] = localName
        }
        
        return dict
    }
    
    private var sendingEOM = false;
    
    private func sendEOM(characteristic:CBMutableCharacteristic!, respond:EMBluetoothDataSend!) -> Bool {
        guard let data = respond else {
            return false
        }
        
        if sendData("EOM".dataUsingEncoding(NSUTF8StringEncoding)!, characteristic: characteristic) {
            sendingEOM = false
            print("Sent: EOM")
            
            data.respond.didSend(respond.data, timeinterval: NSDate().timeIntervalSince1970 - data.timestamp)
            
            return true
        }
        return false
    }
    
    private func sendData(data:NSData, characteristic:CBMutableCharacteristic) -> Bool {
        // send it
        return (peripheralManager?.updateValue(
            data,
            forCharacteristic: characteristic,
            onSubscribedCentrals: nil
            ))!
    }
    
    private func findOrCreateService(characteristic:CBMutableCharacteristic!) -> EMBluetoothService! {
        let service = findService(characteristic.UUID)
        if service != nil {
            return service
        }
        return createService(characteristic)
    }
    
    private func createService(characteristic: CBMutableCharacteristic!) -> EMBluetoothService! {
        let service = EMBluetoothService(characteristic:characteristic, delegate:self)
        services?.append(service)
        return service
    }
    
    private func findService(uuid: CBUUID!) -> EMBluetoothService! {
        for service in services! {
            if service.characteristic.UUID.UUIDString == uuid.UUIDString {
                return service
            }
        }
        return nil
    }
    
    private func sendData() {
        guard sendList.count != 0 else {
            return
        }
        
        guard let data = sendList.first else {
            return
        }
        
        guard let dataToSend = data.data,
            let characteristic = data.characteristic else {
            return
        }
        
        if data.timestamp == 0 {
            data.timestamp = NSDate().timeIntervalSince1970
        }
        
        if sendingEOM {
            if sendEOM(characteristic, respond: data) {
                sendList.removeAtIndex(0)
                return
            }
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        guard data.sendDataIndex < data.data.length else {
            // No data left.  Do nothing
            return
        }
        
        while true {
            var amountToSend = dataToSend.length - data.sendDataIndex
            
            // Can't be longer than 20 bytes
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = NSData(
                bytes: dataToSend.bytes + data.sendDataIndex,
                length: amountToSend
            )
            
            if (!sendData(chunk, characteristic: characteristic)) {
                return
            }
            
            // It did send, so update our index
            data.sendDataIndex += amountToSend;
            
            // Was it the last one?
            if (data.sendDataIndex >= dataToSend.length) {
                
                sendingEOM = true
                
                if sendingEOM {
                    if sendEOM(characteristic, respond: data) {
                        sendList.removeAtIndex(0)
                    }
                }
                
                return
            }
        }
    }
    
    //MARK:- EMBluetoothService Delegate
    public func send(data:NSData, characteristic:CBMutableCharacteristic, respond:EMBluetoothServiceRespond) {
        sendList.append(EMBluetoothDataSend(data:data, characteristic:characteristic, respond:respond))
        
        sendData();
    }
    
    //MARK: - CBPeripheralManager Delegate
    public func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        let state = peripheral.state
        if (state != CBPeripheralManagerState.PoweredOn) {
            return
        }
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        let service = findService(characteristic.UUID)
        guard service != nil else {
            return
        }
        
        service.didSubscribe(central)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        let service = findService(characteristic.UUID)
        guard service != nil else {
            return
        }
        
        service.didSubscribe(central)
    }
    
    public func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print(error)
    }
    
    public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        print(error)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        
        let service = findService(request.characteristic.UUID)
        var result:CBATTError = .RequestNotSupported
        if service != nil {
            result = service.centralRequetsForData(request)
        }
        else if centralRequests != nil {
            peripheral.respondToRequest(request, withResult: .RequestNotSupported)
            result = centralRequests!(request)
        }
        
        peripheral.respondToRequest(request, withResult: result)
    }
    
    public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests:[CBATTRequest]) {
        
        for request in requests {
            
            let service = findService(request.characteristic.UUID)
            var result:CBATTError = .RequestNotSupported
            if service != nil {
                result = service.centralSentData(request)
            }
            else if centralResponds != nil {
                peripheral.respondToRequest(request, withResult: .RequestNotSupported)
                result = centralResponds!(request)
            }

            peripheral.respondToRequest(request, withResult:result)
        }
    }
}
