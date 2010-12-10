#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#import <Foundation/Foundation.h>
#ifdef USE_LOCAL_GROWL
#import <Growl/Growl.h>
#else
#import <Growl.h>
#endif
#import <objc/runtime.h>

static Class GrowlAppBridge;

@interface Growl : NSObject <GrowlApplicationBridgeDelegate> {
    NSDictionary* info_;
}
+(Growl*)sharedInstance;
-(NSDictionary*)info;
-(void)setInfo:(NSDictionary*)newInfo;
@end

@implementation Growl

+(Growl*)sharedInstance {
    static Growl* obj = nil;
    if (nil == obj) {
        obj = [[Growl alloc] init];
        [obj setInfo:nil];
    }
    return obj;
}

-(NSDictionary*)info {
    return info_;
}

-(void)setInfo:(NSDictionary*)newInfo {
    if (nil != info_) {
        [info_ release];
    }
    info_ = [newInfo retain];
}

-(NSDictionary*)registrationDictionaryForGrowl {
    return info_;
}

-(void)dealloc {
    [info_ release];
    [super dealloc];
}

@end

XS(growl_installed) {
    dXSARGS;

    SV* sv;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if ([GrowlAppBridge isGrowlInstalled]) {
        sv = newSViv(1);
    }
    else {
        sv = newSViv(0);
    }
    [pool drain];

    ST(0) = sv_2mortal(sv);

    XSRETURN(1);
}

XS(growl_running) {
    dXSARGS;

    SV* sv;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if ([GrowlAppBridge isGrowlRunning]) {
        sv = newSViv(1);
    }
    else {
        sv = newSViv(0);
    }
    [pool drain];

    ST(0) = sv_2mortal(sv);

    XSRETURN(1);
}

XS(growl_register) {
    dXSARGS;

    if (items < 3) {
        Perl_croak(aTHX_ "Usage: _growl_register($app_name, \\@allNotifications, \\@defaultNotifications[, $iconFile])");
    }

    SV* sv_appName = ST(0);
    SV* sv_allNotif = ST(1);
    SV* sv_defaultNotif = ST(2);

    if (!SvROK(sv_allNotif) || !SvROK(sv_defaultNotif) ||
        SVt_PVAV != SvTYPE(SvRV(sv_allNotif)) ||
        SVt_PVAV != SvTYPE(SvRV(sv_defaultNotif))) {

        Perl_croak(aTHX_ "Error: \\@allNotifications and \\@defaultNotifications should be ArrayRef");
    }

    STRLEN len;
    char* ptr;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    ptr = SvPV(sv_appName, len);
    NSString* appName = [NSString stringWithUTF8String:ptr];

    SV** svp;
    AV* av;
    int i, alen;

    NSMutableArray* all = [NSMutableArray array];
    av     = (AV*)SvRV(sv_allNotif);
    alen = av_len(av) + 1;
    for (i = 0; i < alen; ++i) {
        svp = av_fetch(av, i, 0);
        if (svp) {
            ptr = SvPV(*svp, len);
            [all addObject:[NSString stringWithUTF8String:ptr]];
        }
    }

    NSMutableArray* defaults = [NSMutableArray array];
    av     = (AV*)SvRV(sv_defaultNotif);
    alen = av_len(av) + 1;
    for (i = 0; i < alen; ++i) {
        svp = av_fetch(av, i, 0);
        if (svp) {
            ptr = SvPV(*svp, len);
            [defaults addObject:[NSString stringWithUTF8String:ptr]];
        }
    }

    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithInt:1],     GROWL_TICKET_VERSION,
                                            @"org.unknownplace.cocoagrowl", GROWL_APP_ID,
                                            appName,                        GROWL_APP_NAME,
                                            all,                            GROWL_NOTIFICATIONS_ALL,
                                            defaults,                       GROWL_NOTIFICATIONS_DEFAULT,
                                       nil];

    [[Growl sharedInstance] setInfo:info];

    [pool drain];

    XSRETURN(0);
}

XS(growl_notify) {
    dXSARGS;

    if (items < 3) {
        Perl_croak(aTHX_ "Usage: _growl_notify($title, $description, $name)");
    }

    SV* sv_title = ST(0);
    SV* sv_desc  = ST(1);
    SV* sv_name  = ST(2);

    STRLEN len;
    char* s;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    s = SvPV(sv_title, len);
    NSString* title = [NSString stringWithUTF8String:s];

    s = SvPV(sv_desc, len);
    NSString* description = [NSString stringWithUTF8String:s];

    s = SvPV(sv_name, len);
    NSString* name = [NSString stringWithUTF8String:s];

    [GrowlAppBridge setGrowlDelegate:[Growl sharedInstance]];

    [GrowlAppBridge notifyWithTitle:title
                        description:description
                   notificationName:name
                           iconData:nil
                           priority:0
                           isSticky:NO
                       clickContext:nil];

    [pool drain];

    XSRETURN(0);
}

XS(boot_Cocoa__Growl) {
    SV* dir = get_sv("Cocoa::Growl::FRAMEWORK_DIR", FALSE);

    STRLEN len;
    char* d = SvPV(dir, len);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    GrowlAppBridge = objc_getClass("GrowlApplicationBridge");
    if (!GrowlAppBridge) {
        NSBundle* growl = [NSBundle bundleWithPath:[NSString stringWithUTF8String:d]];
        NSError* err = nil;
        if (growl && [growl loadAndReturnError:&err]) {
            //NSLog(@"growl load success");
            GrowlAppBridge = objc_getClass("GrowlApplicationBridge");
        }
        else {
            if (nil != err) {
                Perl_croak(aTHX_ "Coudn't load Growl framework: %s\n",
                    [[err localizedDescription] UTF8String]);
            }
            else {
                Perl_croak(aTHX_ "Coudn't initialize Growl bundle\n");
            }
        }
    }

    [pool drain];

    newXS("Cocoa::Growl::growl_installed", growl_installed, __FILE__);
    newXS("Cocoa::Growl::growl_running", growl_running, __FILE__);
    newXS("Cocoa::Growl::_growl_register", growl_register, __FILE__);
    newXS("Cocoa::Growl::_growl_notify", growl_notify, __FILE__);
}
