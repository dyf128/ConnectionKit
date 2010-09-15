//
//  KTElementPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSPlugInWrapper.h"


typedef enum {
	KTPluginCategoryUnknown = 0,
	KTPluginCategoryTopLevel = 1,		// In case we have any plug-ins that we don't want to show up in a category
	KTPluginCategoryIndex = 2,
	KTPluginCategoryBadge,
	KTPluginCategoryEmbedded,
	KTPluginCategorySocial,				// Should Social and Embedded be folded together?
	KTPluginCategoryOther
} KTPluginCategory;


@class SVGraphicFactory;


@interface KTElementPlugInWrapper : KSPlugInWrapper
{
@private
    SVGraphicFactory    *_factory;
    
	NSString    *_templateHTML;
}

+ (NSSet *)pageletPlugins;
+ (NSSet *)pagePlugins;

// Inserts one item per known collection preset into aMenu at the specified index.
+ (void)populateMenuWithCollectionPresets:(NSMenu *)aMenu atIndex:(NSUInteger)index;

- (SVGraphicFactory *)graphicFactory;

- (KTPluginCategory)category;

@end
