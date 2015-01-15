//
//  AppDelegate.m
//  testBLE
//
//  Created by tojo on 2014/12/01.
//  Copyright (c) 2014年 gotojo. All rights reserved.
//

#import "AppDelegate.h"

// サービスUUID:Immediate Alert
NSString *kUUIDServiceImmediateAlert = @"1802";
// サービスUUID:Battery Service
NSString *kUUIDServiceBatteryService = @"180F";
// キャラクタリスティックUUID:Alert Level
NSString *kUUIDCharacteristicsAlertLevel = @"2A06";
// キャラクタリスティックUUID:Battery Level
NSString *kUUIDCharacteristicsBatteryLevel = @"2A19";
@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong) CBCentralManager* centralManager;
@property (strong) CBPeripheral* peripheral;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - Start/Stop Scan methods
/*
 Request CBCentralManager to scan for health thermometer peripherals using service UUID 0x1809
 */
- (void)startScan
{
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
    
    [self.centralManager scanForPeripheralsWithServices:nil options:options];
}

/*
 Request CBCentralManager to stop scanning for health thermometer peripherals
 */
- (void)stopScan
{
    [self.centralManager stopScan];
}

#pragma mark - LE Capable Platform/Hardware check
/*
 Uses CBCentralManager to check whether the current platform/hardware supports Bluetooth LE. An alert is raised if Bluetooth LE is not enabled or is not supported.
 */
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    
    switch ([self.centralManager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            [self startScan];
            NSLog(@"startScan");
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            NSLog(@"Unknown state");
            return FALSE;
            
    }
    
    NSLog(@"Central manager state: %@", state);
    
    //[self cancelScanSheet:nil];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert setIcon:[[NSImage alloc] initWithContentsOfFile:@"Thermometer"]];
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}

#pragma mark - CBManagerDelegate methods
/*
 Invoked whenever the central manager's state is updated.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState");
    [self isLECapableHardware];
}

/*
 Invoked when the central discovers thermometer peripheral while scanning.
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    //NSLog(@"Did discover peripheral. peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral, RSSI, peripheral.UUID, advertisementData);
    NSLog(@"Did discover peripheral. peripheral: %@ rssi: %@, advertisementData: %@ ", peripheral, RSSI, advertisementData);
    if (peripheral.state == CBPeripheralStateDisconnected) {
        if ([peripheral.name compare:@"mi.1"] == NSOrderedSame) {
            NSLog(@"found mi.1");
            self.peripheral = peripheral;
            [self.centralManager connectPeripheral:self.peripheral options:nil];
        }
    }
}

/*
 Invoked when the central manager retrieves the list of known peripherals.
 Automatically connect to first known peripheral
 */
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %lu - %@", [peripherals count], peripherals);
}

/*
 Invoked whenever a connection is succesfully created with the peripheral.
 Discover available services on the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Did connect to peripheral: %@", peripheral);
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
}

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Did Disconnect to peripheral: %@ with error = %@", peripheral, [error localizedDescription]);
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", peripheral, [error localizedDescription]);
}

#pragma mark - CBPeripheralDelegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"Discovered services for %@ with error: %@", peripheral.name, [error localizedDescription]);
        return;
    }
    for (CBService * service in peripheral.services)
    {
        NSLog(@"Service found with UUID: %@", service.UUID);
        if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
        {
            /* GAP (Generic Access Profile) - discover device name characteristic */
            [self.peripheral discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:CBUUIDDeviceNameString]]  forService:service];
            //[self.peripheral discoverIncludedServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:CBUUIDDeviceNameString]]  forService:service];
        }
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kUUIDServiceImmediateAlert]])
        {
            // Immediate Alertサービスを発見した場合、Alert Levelキャラクタリスティックの探索を開始
            [self.peripheral discoverCharacteristics:[NSArray arrayWithObjects:[CBUUID UUIDWithString:kUUIDCharacteristicsAlertLevel], nil] forService:service];
        }
        else if ([service.UUID isEqual:[CBUUID UUIDWithString:kUUIDServiceBatteryService]])
        {
            // Battery Serviceサービスを発見した場合、Battery Levelキャラクタリスティックの探索を開始
            [self.peripheral discoverCharacteristics:[NSArray arrayWithObjects:[CBUUID UUIDWithString:kUUIDCharacteristicsBatteryLevel], nil] forService:service];
        }
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:@"1809"]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            /* Set indication on temperature measurement */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1C"]])
            {
                NSLog(@"Found a Temperature Measurement Characteristic");
            }
            /* Set notification on intermediate temperature measurement */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1E"]])
            {
                NSLog(@"Found a Intermediate Temperature Measurement Characteristic");
            }
            /* Write value to measurement interval characteristic */
            if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A21"]])
            {
                //uint16_t val = 2;
                //NSData * valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
                //[testPeripheral writeValue:valData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                NSLog(@"Found a Temperature Measurement Interval Characteristic - Write interval value");
            }
        }
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            /* Read manufacturer name */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
            {
                //[testPeripheral readValueForCharacteristic:characteristic];
                NSLog(@"Found a Device Manufacturer Name Characteristic - Read manufacturer name");
            }
        }
    }
    
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *characteristic in service.characteristics)
        {
            /* Read device name */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
                //[testPeripheral readValueForCharacteristic:characteristic];
                NSLog(@"Found a Device Name Characteristic - Read device name");
            }
        }
    }
}

/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
}

/*
 Invoked upon completion of a -[writeValue:forCharacteristic:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error writing value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
}

/*
 Invoked upon completion of a -[setNotifyValue:forCharacteristic:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating notification state for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"Updated notification state for characteristic %@ (newState:%@)", characteristic.UUID, [characteristic isNotifying] ? @"Notifying" : @"Not Notifying");
    
    if( ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1C"]]) ||
       ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1E"]]) )
    {
        /* Set start/stop button depending on characteristic notifcation/indication */
        if( [characteristic isNotifying] )
        {
        }
        else
        {
        }
    }
}

@end
