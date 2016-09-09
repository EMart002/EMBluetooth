//
//  EMBluetoothListenerService.swift
//  Business Services
//
//  Created by Martin Eberl on 07.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth

public class EMBluetoothServiceListener: NSObject, CBCentralManagerDelegate, EMBluetoothServiceDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager?
    private var discoveredPeripheral: [CBPeripheral]?
    private var internalActive:Bool = false
    
    private(set) var services:[EMBluetoothService]?
    
    public var scan:Bool {
        set {
            guard centralManager?.state == .PoweredOn else {
                return
            }
            
            internalActive = newValue
            
            if internalActive {
                var serviceIds = [CBUUID]()
                for service in services! {
                    serviceIds.append(service.uuid)
                }
                centralManager?.scanForPeripheralsWithServices(serviceIds, options:[
                    CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(bool: true)
                    ])
            }
            else {
                centralManager?.stopScan()
            }
        }
        get {
            return internalActive
        }
    }
    
    deinit {
        scan = false
    }
    
    //MARK:- Init Methods
    public override init() {
        super.init()
        
        discoveredPeripheral = [CBPeripheral]()
        centralManager = CBCentralManager(delegate:self, queue: nil)
    }
    
    //MARK:- Public Methods
    public func listen(serviceId:CBUUID!) -> EMBluetoothService {
        var service = findService(serviceId)
        if service != nil {
            return service
        }
        
        service = createService(serviceId)
        if scan {
            scan = true
        }
        
        return service
    }
    
    public func stopListening(serviceId:CBUUID!) {
        var i = 0
        var found = false
        for service in services! {
            if service.uuid.UUIDString == serviceId.UUIDString {
                found = true
                break
            }
            i += 1
        }
        
        if found {
            services?.removeAtIndex(i)
            scan = true
        }
    }
    
    public func stopListening() {
        services = [EMBluetoothService]()
        scan = false
    }
    
    public func findService(uuid: CBUUID!) -> EMBluetoothService! {
        for service in services! {
            if service.characteristic.UUID.UUIDString == uuid.UUIDString {
                return service
            }
        }
        return nil
    }
    
    //MARK:- Private Methods
    private func findOrCreateService(uuid: CBUUID!) -> EMBluetoothService! {
        let service = findService(uuid)
        if service != nil {
            return service
        }
        return createService(uuid)
    }
    
    private func createService(uuid: CBUUID!) -> EMBluetoothService! {
        let service = EMBluetoothService(uuid:uuid, delegate:self)
        services?.append(service)
        return service
    }
    
    //MARK:- CBCentralManager Delegate
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        guard central.state  == .PoweredOn else {
            return
        }
        scan = true
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        
        
        // Reject any where the value is above reasonable range
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        
        //        if  RSSI.integerValue < -15 && RSSI.integerValue > -35 {
        //            println("Device not at correct range")
        //            return
        //        }
        
        print("Discovered \(peripheral.name) at \(RSSI)")
        
        // Ok, it's in range - have we already seen it?
        
        if !(discoveredPeripheral?.contains(peripheral))! {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            discoveredPeripheral?.append(peripheral)
            
            // And connect
            print("Connecting to peripheral \(peripheral)")
            
            centralManager?.connectPeripheral(peripheral, options: nil)
        }
    }
    
    /** If the connection fails for whatever reason, we need to deal with it.
     */
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")
        
        cleanup(peripheral)
    }
    
    /** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        scan = false
        
        print("Scanning stopped")
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([transferServiceUUID])
    }
    
    /** The Transfer Service was discovered
     */
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            cleanup(peripheral)
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in services {
            peripheral.discoverCharacteristics([transferReadCharacteristicUUID], forService: service)
            peripheral.discoverCharacteristics([transferWriteCharacteristicUUID], forService: service)
        }
    }
    
    /** The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // Deal with errors (if any)
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            cleanup(peripheral)
            return
        }
        
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        // Again, we loop through the array, just in case.
        for characteristic in characteristics {
            // And check if it's the right one
            if characteristic.UUID.isEqual(transferReadCharacteristicUUID) {
                // If it is, subscribe to it
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /** This callback lets us know more data has arrived via notification on the characteristic
     */
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let stringFromData = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding) else {
            print("Invalid data")
            return
        }
        
        // Have we got everything we need?
        if stringFromData.isEqualToString("EOM") {
            // We have, so show the data,
                        // Cancel our subscription to the characteristic
            peripheral.setNotifyValue(false, forCharacteristic: characteristic)
            
            // and disconnect from the peripehral
            centralManager?.cancelPeripheralConnection(peripheral)
        } else {
            // Otherwise, just add the data on to what we already have
            
            // Log it
            print("Received: \(stringFromData)")
        }
    }
    
    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("Error changing notification state: \(error?.localizedDescription)")
        
        // Exit if it's not the transfer characteristic
        guard characteristic.UUID.isEqual(transferReadCharacteristicUUID) else {
            return
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            print("Notification began on \(characteristic)")
        } else { // Notification has stopped
            print("Notification stopped on (\(characteristic))  Disconnecting")
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Peripheral Disconnected")
        discoveredPeripheral = nil
        
        // We're disconnected, so start scanning again
        scan = true
    }
    
    /** Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup(peripheral:CBPeripheral!) {
        // Don't do anything if we're not connected
        // self.discoveredPeripheral.isConnected is deprecated
        guard peripheral.state == .Connected else {
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        guard let services = peripheral.services else {
            cancelPeripheralConnection(peripheral)
            return
        }
        
        for service in services {
            guard let characteristics = service.characteristics else {
                continue
            }
            
            for characteristic in characteristics {
                if characteristic.UUID.isEqual(transferReadCharacteristicUUID) && characteristic.isNotifying {
                    peripheral.setNotifyValue(false, forCharacteristic: characteristic)
                    // And we're done.
                    return
                }
            }
        }
    }
    
    private func cancelPeripheralConnection(peripheral:CBPeripheral!) {
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager?.cancelPeripheralConnection(peripheral)
    }
    
    //MARK:- EMBluetoothService Delegate
    public func send(data:NSData, characteristic:CBMutableCharacteristic, respond:EMBluetoothServiceRespond) {
        
    }
}
