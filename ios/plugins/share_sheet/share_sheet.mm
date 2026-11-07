#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Godot calls these as C++ functions (extern void share_sheet_init();).
// This file is Objective-C++ so the linkage matches. It does not include
// Godot headers: the game writes user://share_sheet_request.json and this
// poller presents UIActivityViewController.

static NSTimer *g_timer = nil;
static NSString *g_docs = nil;
static BOOL g_presenting = NO;

static NSString *share_sheet_path(NSString *name) {
	return [g_docs stringByAppendingPathComponent:name];
}

static void share_sheet_write_result(NSString *value) {
	if (g_docs == nil) {
		return;
	}
	[value writeToFile:share_sheet_path(@"share_sheet_result.txt")
			atomically:YES
			  encoding:NSUTF8StringEncoding
				 error:nil];
}

static UIViewController *share_sheet_host(void) {
	UIWindow *window = nil;
	if (@available(iOS 13.0, *)) {
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) {
				continue;
			}
			UIWindowScene *window_scene = (UIWindowScene *)scene;
			for (UIWindow *candidate in window_scene.windows) {
				if (candidate.isKeyWindow) {
					window = candidate;
					break;
				}
			}
			if (window == nil) {
				window = window_scene.windows.firstObject;
			}
			if (window != nil) {
				break;
			}
		}
	}
	if (window == nil) {
		window = UIApplication.sharedApplication.keyWindow;
	}
	UIViewController *host = window.rootViewController;
	while (host.presentedViewController != nil) {
		host = host.presentedViewController;
	}
	return host;
}

static void share_sheet_poll(void) {
	if (g_presenting || g_docs == nil) {
		return;
	}
	NSString *request_path = share_sheet_path(@"share_sheet_request.json");
	NSData *data = [NSData dataWithContentsOfFile:request_path];
	if (data == nil) {
		return;
	}
	[[NSFileManager defaultManager] removeItemAtPath:request_path error:nil];
	id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	if (![parsed isKindOfClass:[NSDictionary class]]) {
		share_sheet_write_result(@"failed");
		return;
	}
	NSDictionary *payload = (NSDictionary *)parsed;
	NSString *text = payload[@"text"];
	if (![text isKindOfClass:[NSString class]]) {
		text = @"";
	}
	NSString *image_path = payload[@"image"];
	if (![image_path isKindOfClass:[NSString class]]) {
		image_path = @"";
	}
	NSMutableArray *items = [NSMutableArray array];
	if (text.length > 0) {
		[items addObject:text];
	}
	if (image_path.length > 0) {
		UIImage *image = [UIImage imageWithContentsOfFile:image_path];
		if (image != nil) {
			[items addObject:image];
		}
	}
	if (items.count == 0) {
		share_sheet_write_result(@"failed");
		return;
	}
	UIViewController *host = share_sheet_host();
	if (host == nil) {
		share_sheet_write_result(@"failed");
		return;
	}
	UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
	if (sheet.popoverPresentationController != nil) {
		sheet.popoverPresentationController.sourceView = host.view;
		CGRect bounds = host.view.bounds;
		sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1.0, 1.0);
		sheet.popoverPresentationController.permittedArrowDirections = (UIPopoverArrowDirection)0;
	}
	// Written before present so a slow animation cannot look like a miss.
	share_sheet_write_result(@"shown");
	g_presenting = YES;
	[host presentViewController:sheet animated:YES completion:^{
		g_presenting = NO;
	}];
}

void share_sheet_init() {
	if (g_timer != nil) {
		return;
	}
	NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	g_docs = paths.firstObject;
	if (g_docs == nil) {
		return;
	}
	[@"1" writeToFile:share_sheet_path(@"share_sheet_ready")
		   atomically:YES
			 encoding:NSUTF8StringEncoding
				error:nil];
	g_timer = [NSTimer timerWithTimeInterval:0.15 repeats:YES block:^(NSTimer *timer) {
		share_sheet_poll();
	}];
	[[NSRunLoop mainRunLoop] addTimer:g_timer forMode:NSRunLoopCommonModes];
}

void share_sheet_deinit() {
	[g_timer invalidate];
	g_timer = nil;
	g_presenting = NO;
}
