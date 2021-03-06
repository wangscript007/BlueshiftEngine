// Copyright(c) 2017 POLYGONTEK
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http ://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Precompiled.h"
#include "Application.h"

static BE1::CVar    disp_width("disp_width", "1280", BE1::CVar::Flag::Integer | BE1::CVar::Flag::Archive, "");
static BE1::CVar    disp_height("disp_height", "720", BE1::CVar::Flag::Integer | BE1::CVar::Flag::Archive, "");
static BE1::CVar    disp_fullscreen("disp_fullscreen", "0", BE1::CVar::Flag::Bool | BE1::CVar::Flag::Archive, "");
static BE1::CVar    disp_bpp("disp_bpp", "0", BE1::CVar::Flag::Integer | BE1::CVar::Flag::Flag::Archive, "");
static BE1::CVar    disp_frequency("disp_frequency", "0", BE1::CVar::Flag::Integer | BE1::CVar::Flag::Archive, "");

@interface MyWindow : NSWindow

@end

@implementation MyWindow

- (void)moveToCenter {
    NSRect mainDisplayRect = [[NSScreen mainScreen] frame];
    
    NSRect windowRect = [self frame];
    
    NSPoint newPos = NSMakePoint(MAX(0, (mainDisplayRect.size.width - windowRect.size.width) / 2),
                                 MAX(0, (mainDisplayRect.size.height - windowRect.size.height) / 2));
    
    [self setFrameOrigin:newPos];
}

- (void)cascade {
    static NSPoint cascadePos = NSMakePoint(0, 0);
    
    if (cascadePos.x == 0 && cascadePos.y == 0) {
        [self moveToCenter];
    }
    
    cascadePos = [self cascadeTopLeftFromPoint:cascadePos];
}

@end

//---------------------------------------------------------------------------------------

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
    TISInputSourceRef currentKeyboard;
    
    MyWindow *mainWindow;
}

@end

@implementation AppDelegate

- (BOOL)translateKeyCode:(unsigned short)keyCode modifiers:(UInt16)modifiers keyDown:(BOOL)keyDown character:(char32_t *)outChar {
    UInt32 deadKeyState = 0;
    UniChar unicodeChars[4];
    UniCharCount actualLength;
    
    CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    if (!layoutData) {
        return false;
    }
    
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    
    UCKeyTranslate(keyboardLayout,
                   keyCode,
                   keyDown ? kUCKeyActionDown : kUCKeyActionUp,
                   modifiers,
                   LMGetKbdType(),
                   kUCKeyTranslateNoDeadKeysBit,
                   &deadKeyState,
                   sizeof(unicodeChars) / sizeof(unicodeChars[0]),
                   &actualLength,
                   unicodeChars);
    
    if (actualLength == 1) {
        // FIXME: need to implement UTF16 to UTF32 conversion
        *outChar = unicodeChars[0];
        return true;
    }
    
    return false;
}

/* Indexed by Mac virtual keycode values defined above. */
static const struct {
    uint16_t scan;
    BOOL fixed;
} vkey_to_scancode_map[] = {
    { 0x1E,           FALSE },    /* kVK_ANSI_A */
    { 0x1F,           FALSE },    /* kVK_ANSI_S */
    { 0x20,           FALSE },    /* kVK_ANSI_D */
    { 0x21,           FALSE },    /* kVK_ANSI_F */
    { 0x23,           FALSE },    /* kVK_ANSI_H */
    { 0x22,           FALSE },    /* kVK_ANSI_G */
    { 0x2C,           FALSE },    /* kVK_ANSI_Z */
    { 0x2D,           FALSE },    /* kVK_ANSI_X */
    { 0x2E,           FALSE },    /* kVK_ANSI_C */
    { 0x2F,           FALSE },    /* kVK_ANSI_V */
    { 0x56,           TRUE },     /* kVK_ISO_Section */
    { 0x30,           FALSE },    /* kVK_ANSI_B */
    { 0x10,           FALSE },    /* kVK_ANSI_Q */
    { 0x11,           FALSE },    /* kVK_ANSI_W */
    { 0x12,           FALSE },    /* kVK_ANSI_E */
    { 0x13,           FALSE },    /* kVK_ANSI_R */
    { 0x15,           FALSE },    /* kVK_ANSI_Y */
    { 0x14,           FALSE },    /* kVK_ANSI_T */
    { 0x02,           FALSE },    /* kVK_ANSI_1 */
    { 0x03,           FALSE },    /* kVK_ANSI_2 */
    { 0x04,           FALSE },    /* kVK_ANSI_3 */
    { 0x05,           FALSE },    /* kVK_ANSI_4 */
    { 0x07,           FALSE },    /* kVK_ANSI_6 */
    { 0x06,           FALSE },    /* kVK_ANSI_5 */
    { 0x0D,           FALSE },    /* kVK_ANSI_Equal */
    { 0x0A,           FALSE },    /* kVK_ANSI_9 */
    { 0x08,           FALSE },    /* kVK_ANSI_7 */
    { 0x0C,           FALSE },    /* kVK_ANSI_Minus */
    { 0x09,           FALSE },    /* kVK_ANSI_8 */
    { 0x0B,           FALSE },    /* kVK_ANSI_0 */
    { 0x1B,           FALSE },    /* kVK_ANSI_RightBracket */
    { 0x18,           FALSE },    /* kVK_ANSI_O */
    { 0x16,           FALSE },    /* kVK_ANSI_U */
    { 0x1A,           FALSE },    /* kVK_ANSI_LeftBracket */
    { 0x17,           FALSE },    /* kVK_ANSI_I */
    { 0x19,           FALSE },    /* kVK_ANSI_P */
    { 0x1C,           TRUE },     /* kVK_Return */
    { 0x26,           FALSE },    /* kVK_ANSI_L */
    { 0x24,           FALSE },    /* kVK_ANSI_J */
    { 0x28,           FALSE },    /* kVK_ANSI_Quote */
    { 0x25,           FALSE },    /* kVK_ANSI_K */
    { 0x27,           FALSE },    /* kVK_ANSI_Semicolon */
    { 0x2B,           FALSE },    /* kVK_ANSI_Backslash */
    { 0x33,           FALSE },    /* kVK_ANSI_Comma */
    { 0x35,           FALSE },    /* kVK_ANSI_Slash */
    { 0x31,           FALSE },    /* kVK_ANSI_N */
    { 0x32,           FALSE },    /* kVK_ANSI_M */
    { 0x34,           FALSE },    /* kVK_ANSI_Period */
    { 0x0F,           TRUE },     /* kVK_Tab */
    { 0x39,           TRUE },     /* kVK_Space */
    { 0x29,           FALSE },    /* kVK_ANSI_Grave */
    { 0x0E,           TRUE },     /* kVK_Delete */
    { 0,              FALSE },    /* 0x34 unused */
    { 0x01,           TRUE },     /* kVK_Escape */
    { 0x38 | 0x100,   TRUE },     /* kVK_RightCommand */
    { 0x38,           TRUE },     /* kVK_Command */
    { 0x2A,           TRUE },     /* kVK_Shift */
    { 0x3A,           TRUE },     /* kVK_CapsLock */
    { 0,              FALSE },    /* kVK_Option */
    { 0x1D,           TRUE },     /* kVK_Control */
    { 0x36,           TRUE },     /* kVK_RightShift */
    { 0,              FALSE },    /* kVK_RightOption */
    { 0x1D | 0x100,   TRUE },     /* kVK_RightControl */
    { 0,              FALSE },    /* kVK_Function */
    { 0x68,           TRUE },     /* kVK_F17 */
    { 0x53,           TRUE },     /* kVK_ANSI_KeypadDecimal */
    { 0,              FALSE },    /* 0x42 unused */
    { 0x37,           TRUE },     /* kVK_ANSI_KeypadMultiply */
    { 0,              FALSE },    /* 0x44 unused */
    { 0x4E,           TRUE },     /* kVK_ANSI_KeypadPlus */
    { 0,              FALSE },    /* 0x46 unused */
    { 0x59,           TRUE },     /* kVK_ANSI_KeypadClear */
    { 0 | 0x100,      TRUE },     /* kVK_VolumeUp */
    { 0 | 0x100,      TRUE },     /* kVK_VolumeDown */
    { 0 | 0x100,      TRUE },     /* kVK_Mute */
    { 0x35 | 0x100,   TRUE },     /* kVK_ANSI_KeypadDivide */
    { 0x1C | 0x100,   TRUE },     /* kVK_ANSI_KeypadEnter */
    { 0,              FALSE },    /* 0x4D unused */
    { 0x4A,           TRUE },     /* kVK_ANSI_KeypadMinus */
    { 0x69,           TRUE },     /* kVK_F18 */
    { 0x6A,           TRUE },     /* kVK_F19 */
    { 0x0D | 0x100,   TRUE },     /* kVK_ANSI_KeypadEquals */
    { 0x52,           TRUE },     /* kVK_ANSI_Keypad0 */
    { 0x4F,           TRUE },     /* kVK_ANSI_Keypad1 */
    { 0x50,           TRUE },     /* kVK_ANSI_Keypad2 */
    { 0x51,           TRUE },     /* kVK_ANSI_Keypad3 */
    { 0x4B,           TRUE },     /* kVK_ANSI_Keypad4 */
    { 0x4C,           TRUE },     /* kVK_ANSI_Keypad5 */
    { 0x4D,           TRUE },     /* kVK_ANSI_Keypad6 */
    { 0x47,           TRUE },     /* kVK_ANSI_Keypad7 */
    { 0x6B,           TRUE },     /* kVK_F20 */
    { 0x48,           TRUE },     /* kVK_ANSI_Keypad8 */
    { 0x49,           TRUE },     /* kVK_ANSI_Keypad9 */
    { 0x7D,           TRUE },     /* kVK_JIS_Yen */
    { 0x73,           TRUE },     /* kVK_JIS_Underscore */
    { 0x7E,           TRUE },     /* kVK_JIS_KeypadComma */
    { 0x3F,           TRUE },     /* kVK_F5 */
    { 0x40,           TRUE },     /* kVK_F6 */
    { 0x41,           TRUE },     /* kVK_F7 */
    { 0x3D,           TRUE },     /* kVK_F3 */
    { 0x42,           TRUE },     /* kVK_F8 */
    { 0x43,           TRUE },     /* kVK_F9 */
    { 0x72,           TRUE },     /* kVK_JIS_Eisu */
    { 0x57,           TRUE },     /* kVK_F11 */
    { 0x71,           TRUE },     /* kVK_JIS_Kana */
    { 0x64,           TRUE },     /* kVK_F13 */
    { 0x67,           TRUE },     /* kVK_F16 */
    { 0x65,           TRUE },     /* kVK_F14 */
    { 0,              FALSE },    /* 0x6C unused */
    { 0x44,           TRUE },     /* kVK_F10 */
    { 0,              FALSE },    /* 0x6E unused */
    { 0x58,           TRUE },     /* kVK_F12 */
    { 0,              FALSE },    /* 0x70 unused */
    { 0x66,           TRUE },     /* kVK_F15 */
    { 0x52 | 0x100,   TRUE },     /* kVK_Help */ /* map to Insert */
    { 0x47 | 0x100,   TRUE },     /* kVK_Home */
    { 0x49 | 0x100,   TRUE },     /* kVK_PageUp */
    { 0x53 | 0x100,   TRUE },     /* kVK_ForwardDelete */
    { 0x3E,           TRUE },     /* kVK_F4 */
    { 0x4F | 0x100,   TRUE },     /* kVK_End */
    { 0x3C,           TRUE },     /* kVK_F2 */
    { 0x51 | 0x100,   TRUE },     /* kVK_PageDown */
    { 0x3B,           TRUE },     /* kVK_F1 */
    { 0x4B | 0x100,   TRUE },     /* kVK_LeftArrow */
    { 0x4D | 0x100,   TRUE },     /* kVK_RightArrow */
    { 0x50 | 0x100,   TRUE },     /* kVK_DownArrow */
    { 0x48 | 0x100,   TRUE },     /* kVK_UpArrow */
};

- (void)processKeyEvent:(NSEvent *)event keyDown:(BOOL)keyDown {
    NSUInteger modifierFlags = [event modifierFlags];
    UInt32 modifiers = 0;
    
    if (modifierFlags & NSAlphaShiftKeyMask) {
        modifiers |= alphaLock;
    }
    
    if (modifierFlags & NSShiftKeyMask) {
        modifiers |= shiftKey;
    }
    
    if (modifierFlags & NSControlKeyMask) {
        modifiers |= controlKey;
    }
    
    if (modifierFlags & NSAlternateKeyMask) {
        modifiers |= optionKey;
    }
    
    if (modifierFlags & NSCommandKeyMask) {
        modifiers |= cmdKey;
    }
    
    uint16_t nativeVirtualKey = [event keyCode];
    uint16_t scancode = vkey_to_scancode_map[nativeVirtualKey].scan;
    scancode = (scancode & 0xFF) | (((scancode >> 8) & 1) << 7);
    BE1::platform->QueEvent(BE1::Platform::EventType::Key, scancode, keyDown ? true : false, 0, nullptr);
    
    if (keyDown) {
#if 1
        NSString *str = [event characters];
        const char32_t *chars = (const char32_t *)[str cStringUsingEncoding:NSUTF32LittleEndianStringEncoding];
        char32_t ch = chars[0];
        BE1::platform->QueEvent(BE1::Platform::EventType::Char, ch, 0, 0, nullptr);
#else
        char32_t ch;
        if ([self translateKeyCode:nativeVirtualKey modifiers:modifiers keyDown:keyDown character:&ch]) {
            BE1::platform->QueEvent(BE1::Platform::EventType::Char, ch, 0, 0, nullptr);
        }
#endif
    }
}

- (void)processMaskChangedKey:(unsigned int)keyMask engineKey:(int)engineKey newFlags:(uint32_t)newFlags oldFlags:(uint32_t)oldFlags {
    bool oldOn = (oldFlags & keyMask) != 0;
    bool newOn = (newFlags & keyMask) != 0;
    if (oldOn != newOn) {
        BE1::platform->QueEvent(BE1::Platform::EventType::Key, engineKey, newOn, 0, nullptr);
    }
}

- (void)processFlagsChangedEvent:(NSEvent *)event {
    static uint32_t oldModifierFlags = 0;
    uint32_t newModifierFlags;
    
    newModifierFlags = (uint32_t)[event modifierFlags];
    [self processMaskChangedKey:NSAlternateKeyMask engineKey:BE1::KeyCode::LeftAlt newFlags:newModifierFlags oldFlags:oldModifierFlags];
    [self processMaskChangedKey:NSControlKeyMask engineKey:BE1::KeyCode::LeftControl newFlags:newModifierFlags oldFlags:oldModifierFlags];
    [self processMaskChangedKey:NSShiftKeyMask engineKey:BE1::KeyCode::LeftShift newFlags:newModifierFlags oldFlags:oldModifierFlags];
    oldModifierFlags = newModifierFlags;
}

- (void)processSystemDefinedEvent:(NSEvent *)event {
    static int32_t oldButtons = 0;
    bool isDown;
    
    if ([event subtype] == 7) {
        int32_t buttons = (int32_t)[event data2];
        int32_t buttonsDelta = oldButtons ^ buttons;
        
        if (buttonsDelta & 1) {
            isDown = buttons & 1 ? true : false;
            BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::Mouse1, isDown, 0, nullptr);
        }
        
        if (buttonsDelta & 2) {
            isDown = buttons & 2 ? true : false;
            BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::Mouse2, isDown, 0, nullptr);
        }
        
        if (buttonsDelta & 4) {
            isDown = buttons & 4 ? true : false;
            BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::Mouse3, isDown, 0, nullptr);
        }
        
        if (buttonsDelta & 8) {
            isDown = buttons & 8 ? true : false;
            BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::Mouse4, isDown, 0, nullptr);
        }
        
        if (buttonsDelta & 16) {
            isDown = buttons & 16 ? true : false;
            BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::Mouse5, isDown, 0, nullptr);
        }
        
        oldButtons = buttons;
    }
}

- (void)processMouseMovedEvent:(NSEvent *)event {
    NSView *view = mainWindow.contentView;
    NSPoint mouseLocation =  [view convertPoint:[event locationInWindow] fromView:nil];
    mouseLocation.y = view.frame.size.height - mouseLocation.y;
    
    BE1::platform->QueEvent(BE1::Platform::EventType::MouseMove, mouseLocation.x, mouseLocation.y, 0, nullptr);
}

- (void)processMouseWheelEvent:(NSEvent *)event {
    if ([event deltaY] > 0.0) {
        BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::MouseWheelUp, true, 0, nullptr);
        BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::MouseWheelUp, false, 0, nullptr);
    } else {
        BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::MouseWheelDown, true, 0, nullptr);
        BE1::platform->QueEvent(BE1::Platform::EventType::Key, BE1::KeyCode::MouseWheelDown, false, 0, nullptr);
    }
}

- (void)processEvent:(NSEvent *)event {
    NSEventType eventType = [event type];
    
    switch (eventType) {
        case NSKeyDown: {
        case NSKeyUp:
            [self processKeyEvent:event keyDown:eventType == NSKeyDown ? YES : NO];
            return;
        }
        case NSFlagsChanged:
            [self processFlagsChangedEvent:event];
            break;
        case NSLeftMouseDown:
        case NSLeftMouseUp:
        case NSRightMouseDown:
        case NSRightMouseUp:
        case NSOtherMouseDown:
        case NSOtherMouseUp:
            // ignore simple mouse button event
            break;
        case NSSystemDefined:
            [self processSystemDefinedEvent:event];
            break;
        case NSMouseMoved:
        case NSLeftMouseDragged:
        case NSRightMouseDragged:
        case NSOtherMouseDragged:
            [self processMouseMovedEvent:event];
            break;
        case NSScrollWheel:
            [self processMouseWheelEvent:event];
            break;
        default:
            break;
    }
    
    [NSApp sendEvent: event];
}

- (MyWindow *)createGLWindow:(NSSize)size title:(NSString *)title {
    NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask;
    
    NSRect contentRect = NSMakeRect(0, 0, size.width, size.height);
    
    MyWindow *window = [[MyWindow alloc] initWithContentRect:contentRect
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    [window setDelegate:self];
    
    [window setTitle:title];
    [window setBackgroundColor:[NSColor grayColor]];
    [window setOpaque:YES];
    [window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenPrimary];
    
    [window cascade];
    
    return window;
}

- (void)destroyGLWindow:(MyWindow *)window {
    [window close];
}

static void DisplayContext(BE1::RHI::Handle contextHandle, void *dataPtr) {
    app.Draw();
}

- (void)initInstance {
    BE1::Engine::InitParms initParms;

    const NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    for (int i = 1; i < arguments.count; i++) { // skip executable path
        const char *str = (const char *)[arguments[i] cStringUsingEncoding:NSUTF8StringEncoding];
        initParms.args.AppendArg(str);
    }

    BE1::Str playerDir = BE1::PlatformFile::ExecutablePath();
    playerDir.AppendPath("../../..");
    initParms.baseDir = playerDir;

    BE1::Str dataDir = playerDir + "/Data";

    BE1::Str assetDir = dataDir;
    assetDir.AppendPath("Contents", '/');

    initParms.searchPath = assetDir + ";" + dataDir;

    BE1::Engine::Init(&initParms);

    BE1::resourceGuidMapper.Read("Data/guidmap");

    currentKeyboard = TISCopyCurrentKeyboardInputSource();

    char fullTitle[128];
    BE1::Str::snPrintf(fullTitle, sizeof(fullTitle), "%s %s %s %s", "Blueshift Player", BE1::PlatformProcess::PlatformName(), __DATE__, __TIME__);
    NSString *nsFullTitle = (__bridge NSString *)StringToCFString(fullTitle);

    mainWindow = [self createGLWindow:NSMakeSize(1280, 720) title:nsFullTitle];

    BE1::renderSystem.InitRHI((__bridge BE1::RHI::WindowHandle)mainWindow);

    BE1::gameClient.Init((__bridge BE1::RHI::WindowHandle)mainWindow, true);
    
    app.mainRenderContext = BE1::renderSystem.AllocRenderContext(true);
    app.mainRenderContext->Init((__bridge BE1::RHI::WindowHandle)[mainWindow contentView], 1280, 720, DisplayContext, nullptr);

    app.mainRenderContext->OnResize(1280, 720);

    app.OnApplicationResize(1280, 720);

    [mainWindow makeKeyAndOrderFront:nil];

    if (disp_fullscreen.GetBool()) {
        [mainWindow toggleFullScreen:nil];
        //app.mainRenderContext->SetFullscreen(disp_width.GetInteger(), disp_height.GetInteger());
    }

    BE1::platform->AppActivate(true, false);

    app.Init();

    app.LoadAppScript("Application");

    app.StartAppScript();
}

- (void)shutdownInstance {
    app.Shutdown();

    app.mainRenderContext->Shutdown();
    BE1::renderSystem.FreeRenderContext(app.mainRenderContext);

    [self destroyGLWindow:mainWindow];

    BE1::gameClient.Shutdown();

    BE1::Engine::Shutdown();

    CFRelease(currentKeyboard);
}

- (void)runFrameInstance:(int)elapsedMsec {
    BE1::Engine::RunFrame(elapsedMsec);
        
    BE1::gameClient.RunFrame();
        
    app.Update();
        
    BE1::gameClient.EndFrame();
        
    app.mainRenderContext->Display();
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    MyWindow *window = [notification object];

    // set window is resizable to make fullscreen window
    NSInteger oldStyleMask = [window styleMask];
    [window setStyleMask:oldStyleMask | NSResizableWindowMask];

    NSSize size = [[window contentView] frame].size;

    BE1::rhi.SetFullscreen(app.mainRenderContext->GetContextHandle(), size.width, size.height);
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    MyWindow *window = [notification object];

    // set window is non-resizable not to allow resizable window
    NSInteger oldStyleMask = [window styleMask];
    [window setStyleMask:oldStyleMask & ~NSResizableWindowMask];

    BE1::rhi.ResetFullscreen(app.mainRenderContext->GetContextHandle());
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self initInstance];
    
    int t0 = BE1::PlatformTime::Milliseconds();
    
    while (1) {
        int t = BE1::PlatformTime::Milliseconds();
        int elapsedMsec = t - t0;
        if (elapsedMsec > 1000) {
            elapsedMsec = 1000;
        }

        t0 = t;
        
        @autoreleasepool {
            while (NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                                       untilDate:nil
                                                          inMode:NSDefaultRunLoopMode
                                                         dequeue:YES]) {
                [self processEvent:event];
            }
        }
        
        [self runFrameInstance:elapsedMsec];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self shutdownInstance];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    BE1::Str workingDir = argv[0];
    workingDir.StripFileName();
    workingDir.AppendPath("../../.."); // Strip "Player.app/Contents/MacOS"
    workingDir.CleanPath(PATHSEPERATOR_CHAR);
    chdir(workingDir.c_str());
    
    Class appDelegateClass = NSClassFromString(@"AppDelegate");
    id appDelegate = [[appDelegateClass alloc] init];
    [[NSApplication sharedApplication] setDelegate:appDelegate];
    
    return NSApplicationMain(argc, argv);
}
