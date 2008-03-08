//
//  ContinueReadingLinkTextBlock.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "ContinueReadingLinkTextBlock.h"

#import "KTPage.h"

#import "NSString-Utilities.h"


@implementation ContinueReadingLinkTextBlock

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[myTargetPage release];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTPage *)targetPage { return myTargetPage; }

- (void)setTargetPage:(KTPage *)page
{
	[page retain];
	[myTargetPage release];
	myTargetPage = page;
}

#pragma mark -
#pragma mark HTML

- (NSString *)outerHTML:(KTHTMLGenerationPurpose)purpose
{
	NSString *result = [NSString stringWithFormat:@"<span id=\"%@\" class=\"kLine\">\r%@\r</span>",
												  [self DOMNodeID],
												  [self innerHTML:purpose]];
	
	return result;
}

/*	Convert @@ to the page title
 */
- (NSString *)innerHTML:(KTHTMLGenerationPurpose)purpose
{
	NSString *contentFormat = [self innerEditingHTML];
	NSString *result = [contentFormat stringByReplacing:@"@@" with:[[self targetPage] titleText]];
	return result;
}

/*	When editing we display the exact format string
 */
- (NSString *)innerEditingHTML
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	return result;
}

#pragma mark -
#pragma mark Editing Status

- (BOOL)becomeFirstResponder
{
	// Insert the new HTML
	[[self DOMNode] setInnerHTML:[self innerEditingHTML]];
	
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	BOOL result = [super resignFirstResponder];
	
	if (result)
	{
		[[self DOMNode] setInnerHTML:[self innerHTML:kGeneratingPreview]];
	}
	
	return result;
}

@end
