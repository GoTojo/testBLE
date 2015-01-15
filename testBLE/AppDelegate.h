//
//  AppDelegate.h
//  testBLE
//
//  Created by tojo on 2014/12/01.
//  Copyright (c) 2014年 gotojo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import IOBluetooth;

@interface AppDelegate : NSObject <NSApplicationDelegate,CBCentralManagerDelegate, CBPeripheralDelegate>


@end

