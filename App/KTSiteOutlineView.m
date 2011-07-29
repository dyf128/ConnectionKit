//
//  KTSiteOutlineView.m
//  Marvel
//
//  Created by Terrence Talbot on 11/29/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTSiteOutlineView.h"

#import "KT.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KTPulsatingOverlay.h"
#import "NSOutlineView+KTExtensions.h"

#import "Registration.h"


NSString *kKTSelectedObjectsKey = @"KTSelectedObjects";
NSString *kKTSelectedObjectsClassNameKey = @"KTSelectedObjectsClassName";


@implementation KTSiteOutlineView

#pragma mark Layout

- (NSRect)rectOfRow:(NSInteger)row;
{
    NSRect result = [super rectOfRow:row];
    
    // The first row is special:
    //  1.  Delegate makes the row taller so as to accomodate divider & padding
    //  2.  Draw the cell/highlight as standard height
    //  3.  Offset the cell from top of table slightly so as to mimic a group row
    // Only takes effect during drawing of the row or highlight. Ensures:
    //  A.  Drop indicator draws in correct position
    //  B.  Cell rect marked for display includes divider
    if (_isDrawingRows && row == 0)
    {
        result.origin.y += ICON_GROUP_ROW_SPACING;
        result.size.height = [self rowHeight] + [self intercellSpacing].height; // standard size
    }
    
    return result;
}

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect;
{
    _isDrawingRows = YES;
    @try
    {
        // seems to work best if we draw it before anything else
        if ( row == 0 )
        {
            // draw line to separate root from children
            float width = clipRect.size.width*0.95;
            float lineX = (clipRect.size.width - width)/2.0;
            
            float height = 1; // line thickness
            float lineY;
            if ( [self rowHeight] < LARGE_ICON_CELL_HEIGHT )
            {
                lineY = SMALL_ICON_CELL_HEIGHT+ICON_ROOT_DIVIDER_SPACING;
            }
            else
            {
                lineY = LARGE_ICON_CELL_HEIGHT+ICON_ROOT_DIVIDER_SPACING;
            }
            
            [[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] set];
            [NSBezierPath fillRect:NSMakeRect(lineX, lineY, width, height)];
            [[NSColor colorWithCalibratedWhite:0.60 alpha:1.0] set];
            [NSBezierPath fillRect:NSMakeRect(lineX, lineY+1, width, height)];                
        }
        [super drawRow:row clipRect:clipRect];
    }
    @finally
    {
        _isDrawingRows = NO;
    }
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect;
{
    _isDrawingRows = YES;
    @try
    {
        [super highlightSelectionInClipRect:clipRect];
    }
    @finally
    {
        _isDrawingRows = NO;
    }
}

#pragma mark Indentation

/*  We want child pages of root to appear as if they were top-level items. Otherwise, there's quite a waste of outline space.
 *  For day-to-day operation, the best bet seems to be customising cell frames.
 *  But annoyingly, drop highlight doesn't respect that. Discoveries:
 *
 *      * -drawRect: calls -_drawDropHightlight
 *      * -_drawDropHighlight calls -levelForRow: for the drop item to determine where to draw, so overriding to decrement super should do the trick
 *      * - However, doing this all the time messes up drag/drop interaction, so we have to be super-cunning and only kick in the custom behaviour mid-draw
 */

- (NSInteger)levelForRow:(NSInteger)row;
{
    // Decrement the level when drawing so drop highlight is correctly placed
    NSInteger result = [super levelForRow:row];
    if (_isDrawing) result--;
    return result;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex;
{
    NSRect result = [super frameOfCellAtColumn:columnIndex row:rowIndex];
    
    // Shunt all but the home page leftwards so top-level pages sit level with it
    if (rowIndex == 0)
    {
        _homePageX = result.origin.x;   // store for future calcs
    }
    else
    {
        // Figure out home page x first if needed
        if (_homePageX == 0.0f) [self frameOfCellAtColumn:columnIndex row:0];
        
        NSUInteger levelToDrawAt = ([super levelForRow:rowIndex] - 1);  // NEED to call super!
        CGFloat left = ([self indentationPerLevel] * levelToDrawAt) + _homePageX;
        
        // Adjust width so that right-hand edge remains the same
        result.size.width += result.origin.x - left;
        result.origin.x = left;
    }
    return result;
}

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
    // Root page doesn't want disclosure triangle…
    if (row > 0)
    {
        NSRect result = [super frameOfOutlineCellAtRow:row];
        NSRect cellFrame = [self frameOfCellAtColumn:0 row:row];
        
        // …everything else needs to move to the left to match that,
        // EXCEPT that Lion does this for us, so only apply if needed
        if (result.origin.x > cellFrame.origin.x)
        {
            result.origin.x -= [self indentationPerLevel];
        }
        return result;
    }
    
    return NSZeroRect;
}

- (void)drawRect:(NSRect)rect;
{
    _isDrawing = YES;
    @try
    {
        [super drawRect:rect];
    }
    @finally
    {
        _isDrawing = NO;
    }
}

#pragma mark Dragging

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[super draggedImage:anImage endedAt:aPoint operation:operation];
	
	// check for drag to Trash
	if ( operation == NSDragOperationDelete )
	{
		NSResponder *controller = [self nextResponder];
        if ([controller respondsToSelector:@selector(delete:)])
        {
            [controller performSelector:@selector(delete:) withObject:self];
        }
	}
}

@synthesize draggedRows = _draggedRows;

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER;
{
    NSImage *result = nil;
    
	// Courtesy of CocoaDev.
	// We need to save the dragged row indexes so that the delegate can choose how to draw the cell.
	// We prevent drawing the stripes to indicate that a row is not publishable in the demo mode.
	self.draggedRows = dragRows;
    @try
    {
        result = [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns
                                              event:dragEvent
                                             offset:dragImageOffset];
    }
    @finally
    {
        self.draggedRows = nil;
    }
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[[KTPulsatingOverlay sharedOverlay] hide];
	[super draggingExited:sender];
}

- (NSCell *)preparedCellAtColumn:(NSInteger)column row:(NSInteger)row;
{
    // Internally, tells delegate the cell will be displayed. Nicely, this means the delegate is unaware we are tampering with cell properties to achieve desired drawing
    NSCell *result = [super preparedCellAtColumn:column row:row];
    
    if (self.draggedRows)
    {
        // When using the source highlight style, NSTableView prepopulates the cell with an attributed string value, effectively hardcoding the text color. Reset that during a drag (for visibility #105959) like so:
        [result setStringValue:[result stringValue]];
    }
    
    return result;
}

#pragma mark Menu

/*- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	int row = [self rowAtPoint:point];
	id item = [self itemAtRow:row];
	
	if ( [item isKindOfClass:[KTPage class]] )
	{				
		// first, establish context and selection
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:[KTPage className] forKey:kKTSelectedObjectsClassNameKey];
		
		// compare selectedItems against item clicked
		NSMutableArray *selectedItems = [[[self selectedItems] mutableCopy] autorelease];
		if ( ![selectedItems containsObject:item] )
		{
			// item is not in selectedItems, select only item and just put that in context
			[context setObject:[NSArray arrayWithObject:item] forKey:kKTSelectedObjectsKey];
			[self selectItem:item];
		}
		else
		{
			[context setObject:selectedItems forKey:kKTSelectedObjectsKey];
		}
		
		// now, build menu
		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Site Outline Contextual Menu"];
		
		// Cut
		NSMenuItem *cutMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Cut", "Cut MenuItem")
															 action:@selector(cutViaContextualMenu:)
													  keyEquivalent:@""];
		[cutMenuItem setRepresentedObject:context];
		[cutMenuItem setTarget:nil];
		[menu addItem:cutMenuItem];
		[cutMenuItem release];
		
		// Copy
		NSMenuItem *copyMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", "Copy MenuItem")
															  action:@selector(copyViaContextualMenu:)
													   keyEquivalent:@""];
		[copyMenuItem setRepresentedObject:context];
		[copyMenuItem setTarget:nil];
		[menu addItem:copyMenuItem];
		[copyMenuItem release];
		
		// Paste
		NSMenuItem *pasteMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Paste", "Paste MenuItem")
															   action:@selector(pasteViaContextualMenu:)
														keyEquivalent:@""];
		[pasteMenuItem setRepresentedObject:context];
		[pasteMenuItem setTarget:nil];
		[menu addItem:pasteMenuItem];
		[pasteMenuItem release];
		
		// Delete
		NSMenuItem *deleteMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", "Delete MenuItem")
																action:@selector(deleteViaContextualMenu:)
														 keyEquivalent:@""];
		[deleteMenuItem setRepresentedObject:context];
		[deleteMenuItem setTarget:nil];
		[menu addItem:deleteMenuItem];
		[deleteMenuItem release];
		
		// --
		[menu addItem:[NSMenuItem separatorItem]];
		
		// Duplicate
		NSMenuItem *duplicateMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Duplicate", "Duplicate MenuItem")
																   action:@selector(duplicateViaContextualMenu:)
															keyEquivalent:@""];
		[duplicateMenuItem setRepresentedObject:context];
		[duplicateMenuItem setTarget:nil];
		[menu addItem:duplicateMenuItem];
		[duplicateMenuItem release];
		
		return [menu autorelease];
	}
    
    // default is just to return super's implementation
	NSMenu *standardMenu = [super menuForEvent:theEvent];
    return standardMenu;
}*/

#pragma mark -
#pragma mark Reloading

// via http://www.corbinstreehouse.com/blog/?p=151
- (void)reloadData
{
	if ( !_isReloadingData )
	{
		_isReloadingData = YES;
		[super reloadData];
		_isReloadingData = NO;
	}
	else
	{
		[self performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
	}
}

@end