/* 
 * Interface for some useful methods:
 * _accessibilityFrontMostApplication give a reference to the application currently being displayed;
 *
 * frontDisplayDidChange is a method that SpringBoard triggers every time the front application changes;
 * is nil when SpringBoard.
 */
@interface SpringBoard : UIApplication
-(id)_accessibilityFrontMostApplication;
-(void)frontDisplayDidChange:(id)arg1;
@end

/* 
 * Just a quick interface to access bundleIdentifier method; this way we can get a string containing the complete
 * bundle identifier of any app currently running.
 */
@interface SBApplication
-(id)bundleIdentifier;
@end

/*
 * Credit where is due: https://github.com/hirakujira/NightShift-Flipswitch
 * Thank you to Optimo on irc.saurik.com, too.
 */

/*
 * This is the interface of the Night Shift toggle in the Control Center; we invoke his methods. 
 */
@interface SBCCNightShiftSetting : NSObject
- (void)_setNightShiftEnabled:(BOOL)enabled;
- (void)_toggleState;
- (id)statusUpdate;
@end

/*
 * The Control Center controller;
 * We're using this interface because we need to get a reference to the instance of the CC.
 */
@interface SBControlCenterController : NSObject
+(id)sharedInstanceIfExists;
@end

/* 
 * The Control Center viewcontroller;
 * It's impossible to get a direct reference to any CC element without this interface.
 */
@interface SBControlCenterViewController : NSObject
@end

@interface SBControlCenterContentView : UIView
@property(retain, nonatomic) id quickLaunchSection; 
@end

//Just a canary to remember if we touched Night Shift or not.
static bool weDisabledNightShift = false;

// Settings reference
NSMutableDictionary *settings;

// Preference path
static NSString *TWEAK_SETTINGS_PATH = @"/User/Library/Preferences/xyz.gsora.temporaryleavesettings.plist";

// Our notification identifier
#define SAVED_STRING (CFStringRef)@"xyz.gsora.temporaryleavesettings.saved"

/*
 * This function load preferences into instance variables.
 */
static void loadPrefs() {
	settings = [[NSMutableDictionary alloc] initWithContentsOfFile:TWEAK_SETTINGS_PATH];
	HBLogDebug(@"Content of prefs: %@", settings);
}

/*
 * This function will return a Night Shift toggle reference.
 *
 * Since there's no directly accessible ivar containing a list of the CC's toggles, MSHookIvar is necessary to
 * achieve what we need.
 */
static SBCCNightShiftSetting *getNightShiftSetting(void) {
	SBControlCenterController* controlCenterController = [%c(SBControlCenterController) sharedInstanceIfExists];
    SBControlCenterViewController* controlCenterViewController = MSHookIvar<SBControlCenterViewController*>(controlCenterController, "_viewController");

	if (controlCenterViewController) {
		SBControlCenterContentView *contentView = MSHookIvar<SBControlCenterContentView*>(controlCenterViewController, "_contentView");
		if (contentView && [contentView respondsToSelector:@selector(quickLaunchSection)]) {
			id quickLaunchSection = contentView.quickLaunchSection;
			NSMutableDictionary* _modulesByID = MSHookIvar<NSMutableDictionary*>(quickLaunchSection, "_modulesByID");
			SBCCNightShiftSetting* target = _modulesByID[@"nightShift"];
			return target;
		}
	}
	return nil;
}

/*
 * This function returns the current Night Shift status.
 *
 * The return value is > 1 if Night Shift is currently enabled.
 */
int getNightShiftStatus(SBCCNightShiftSetting *ns) {
	return MSHookIvar<int>(ns, "_currentStatus");
}

/*
 * Function called when a notification arrives.
 */
static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	loadPrefs();
}

/*
 * Tweak constructor!
 *
 * It loads the preferences by calling loadPrefs(), and sets up a notification observer to update the tweak's preferencese at runtime.
 */
%ctor {
	loadPrefs();
	CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(), 
			NULL, 
			notificationCallback, 
			SAVED_STRING, 
			NULL, 
			CFNotificationSuspensionBehaviorCoalesce
			);
}

%hook SpringBoard

-(void)frontDisplayDidChange:(id)arg1 {
	// get a reference to the current displayed app bundle identifier
	SBApplication *frontApp = [(SpringBoard*)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
	NSString *currentAppID = [frontApp bundleIdentifier];

	// get a reference to the Night Shift toggle
	SBCCNightShiftSetting *k = getNightShiftSetting();
	
	// get the "enabled" status for the single application from preferences
	bool thisAppEnabled = [[settings objectForKey:[NSString stringWithFormat:@"%@-%@", @"EnabledApps", currentAppID]] boolValue];
	if(thisAppEnabled) {
		// if Night Shift is enable, disable it and modify the canary
		if(getNightShiftStatus(k) > 1) {
			[k _toggleState];
			weDisabledNightShift = true;
		}
	} else {
		// if we did disabled Night Shift, re-enable it
		if(weDisabledNightShift) {
			[k _toggleState];
			weDisabledNightShift = 0;
		}
	}

	// continue with the normal flow of the method
	%orig(arg1);
}

%end
