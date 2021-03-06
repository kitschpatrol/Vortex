//
//  KPVortex.m
//  VortexRemote
//
//  Created by Eric Mika on 5/18/14.
//  Copyright (c) 2014 Kitschpatrol. All rights reserved.
//

#import "KPVortex.h"
#import "KPKit.h"
#import "BLE.h"

const char SET_DRILL_SPEED = 'a'; // float from 0 to 1
const char SET_TIME_SCALE = 'b'; // float from 0 to 1
const char SET_LEDS_ALL_ON = 'c'; // no params
const char SET_LEDS_ALL_OFF = 'd'; // no params
const char SET_LED = 'e'; // XXX address XXX red XXX green XXX blue


const char SET_LEDS_ALL_HUE = 'f'; // XXX hue // TODO
const char SET_LEDS_ALL_SATURATION = 'g'; // XXX sat // TODO
const char SET_LEDS_ALL_BRIGHTNESS = 'h'; // XXX bright // TODO




const NSUInteger ledRows = 16;
const NSUInteger ledColumns = 16;

@interface KPVortex () <BLEDelegate>

@property (nonatomic, strong) BLE *bleMini;

@end

@implementation KPVortex

+ (KPVortex *)defaultVortex {
    static KPVortex* sharedInstance = nil;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        sharedInstance = [[KPVortex alloc] init];
    });
    
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        _timeScale = 0.0;
        _drillSpeed = 0.0;
        _drillSpeedMinimum = 0.0;
        _drillSpeedMaximum = 0.75;
        
        _bleMini = [[BLE alloc] init];
        [_bleMini controlSetup];
        _bleMini.delegate = self;
        
        [_bleMini addObserver:self forKeyPath:@"activePeripheral.state" options:0 context:NULL];
    }
    return self;
}

- (void)dealloc {
    [_bleMini removeObserver:self forKeyPath:@"activePeripheral.state"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"activePeripheral.state"]) {
        self.connectionState = self.bleMini.activePeripheral.state;
    }
}

# pragma mark - BLEDelegate

-(void) bleDidReceiveData:(unsigned char *)data length:(int)length{
    //NSData *d = [NSData dataWithBytes:data length:length];
    //NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}


-(void) bleDidConnect {

}

- (void) bleDidDisconnect {

}

# pragma mark - BLE Connection

- (void)connectionTimer:(NSTimer *)timer {
    if(self.bleMini.peripherals.count > 0)
    {
        [self.bleMini connectPeripheral:[self.bleMini.peripherals objectAtIndex:0]];
    }
    else {
        //[activityIndicator stopAnimating];
    }
}

- (void)BLEShieldScan {
    if (self.bleMini.activePeripheral)
        if(self.bleMini.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[self.bleMini CM] cancelPeripheralConnection:[self.bleMini activePeripheral]];
            return;
        }
    
    if (self.bleMini.peripherals)
        self.bleMini.peripherals = nil;
    
    [self.bleMini findBLEPeripherals:3];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
}

- (void)sendMessageToBle:(NSString *)message {
  NSLog(@"Sending message: %@", message);
  
    NSString *s;
    NSData *d;
    
    if (message.length > 16) {
        s = [message substringToIndex:16];
    }
    else {
        s = message;
    }
    
    d = [s dataUsingEncoding:NSUTF8StringEncoding];
    if (self.bleMini.activePeripheral.state == CBPeripheralStateConnected) {
        [self.bleMini write:d];
    }
}


- (void)setDrillSpeed:(CGFloat)drillSpeed {
    _drillSpeed = drillSpeed;
  
    // Send the message
    CGFloat clampedDrillSpeed = KPMap(self.drillSpeed, (CGFloat)0.0, (CGFloat)1.0, self.drillSpeedMinimum, self.drillSpeedMaximum);
    NSString *message = [NSString stringWithFormat:@"%c%.4f\n", SET_DRILL_SPEED, clampedDrillSpeed];
    [self sendMessageToBle:message];
}

- (void)setTimeScale:(CGFloat)timeScale {
  _timeScale = timeScale;

    // Send the message
    NSString *message = [NSString stringWithFormat:@"%c%.5f\n", SET_TIME_SCALE, self.timeScale];
    [self sendMessageToBle:message];
}

- (void)setAllLEDsOn {
  // Send the message
  NSString *message = [NSString stringWithFormat:@"%c\n", SET_LEDS_ALL_ON];
  [self sendMessageToBle:message];
}

- (void)setAllLEDsOff {
  NSString *message = [NSString stringWithFormat:@"%c\n", SET_LEDS_ALL_OFF];
  [self sendMessageToBle:message];
}

- (void)setLEDatPosition:(CGPoint)position toColor:(UIColor *)color {
  // Convert point to array address...
  NSUInteger ledIndex = (((ledRows - 1) - position.y) * ledColumns) + position.x;
  [self setLEDatIndex:ledIndex toColor:color];
}

- (void)setLEDatIndex:(NSUInteger)index toColor:(UIColor *)color {
  // TODO lookup table to map to "real" index?
  CGFloat r, g, b, a;
  [color getRed:&r green:&g blue:&b alpha:&a];
  
#warning WTF, GRB instead of RGB?
  int redComponent = (int)(g * 255.0);
  int greenComponent = (int)(r * 255.0);
  int blueComponent = (int)(b * 255.0);
  
  NSString *message = [NSString stringWithFormat:@"%c%03i%03i%03i%03i\n", SET_LED, index, redComponent, greenComponent, blueComponent];
  [self sendMessageToBle:message];
}


- (void)connect {
    [self BLEShieldScan];
}

- (void)disconnect {
    // TODO
}


@end
