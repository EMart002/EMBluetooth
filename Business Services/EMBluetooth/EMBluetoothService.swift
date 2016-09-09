//
//  EMBluetoothService.swift
//  Business Services
//
//  Created by Martin Eberl on 07.09.16.
//  Copyright © 2016 Styria Digital Services GmbH. All rights reserved.
//

import CoreBluetooth

public protocol EMBluetoothServiceRespond : NSObjectProtocol {
    func didSubscribe(central:CBCentral!)
    func didUnsubscribe(central:CBCentral!)
    func didSend(data:NSData, timeinterval:NSTimeInterval)
    func centralRequetsForData(request:CBATTRequest) -> CBATTError
    func centralSentData(request:CBATTRequest) -> CBATTError
}

public protocol EMBluetoothServiceDelegate : NSObjectProtocol {
    func send(data:NSData, characteristic:CBMutableCharacteristic, respond:EMBluetoothServiceRespond)
}

public class EMBluetoothService: NSObject, EMBluetoothServiceRespond {
    private(set) var characteristic:CBMutableCharacteristic!
    private(set) var uuid:CBUUID!
    
    public weak var delegate:EMBluetoothServiceDelegate?
    public var didSend:(NSData!, NSTimeInterval!->Void)?
    public var requestsData:(CBATTRequest!->CBATTError!)?
    public var receivedData:((CBATTRequest!)->CBATTError!)?
    public var centralSubscriped:(CBCentral!->Void)?
    public var centralUnsubscribed:(CBCentral!->Void)?
    
    //MARK:- Init Methods
    public init(characteristic:CBMutableCharacteristic!, delegate:EMBluetoothServiceDelegate!) {
        self.characteristic = characteristic
        self.delegate = delegate
    }
    
    public init(uuid:CBUUID!, delegate:EMBluetoothServiceDelegate!) {
        self.uuid = uuid
        self.delegate = delegate
    }
    
    //MARK: - Public Methods
    public func send(data:NSData) {
        guard delegate != nil else {
            return
        }
        
        delegate?.send(
            data,
            characteristic:characteristic,
            respond: self)
    }
    
    //MARK: - EMBluetoothServiceRespond
    public func didSend(data: NSData, timeinterval: NSTimeInterval) {
        guard didSend != nil else {
            return
        }
        
        didSend(data, timeinterval: timeinterval)
    }
    
    public func centralRequetsForData(request:CBATTRequest) -> CBATTError {
        guard requestsData != nil else {
            return .RequestNotSupported
        }
        
        return requestsData!(request)
    }
    
    public func centralSentData(request:CBATTRequest) -> CBATTError {
        guard receivedData != nil else {
            return .RequestNotSupported
        }
        
        return receivedData!(request)
    }
    
    public func didSubscribe(central:CBCentral!) {
        guard centralSubscriped != nil else {
            return
        }
        
        return centralSubscriped!(central)
    }
    
    public func didUnsubscribe(central:CBCentral!) {
        guard centralUnsubscribed != nil else {
            return
        }
        
        return centralUnsubscribed!(central)
    }
}
