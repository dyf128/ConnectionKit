//
//  WEKWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//


#import "WEKDOMController.h"
#import "KSSelectionBorder.h"


@class WEKWebEditorView;


@interface WEKWebEditorItem : WEKDOMController
{
  @private
    // Tree
    NSArray             *_childControllers;
    WEKWebEditorItem    *_parentController; // weak ref
    
    BOOL    _selected;
    BOOL    _editing;
}

@property(nonatomic, assign, readonly) WEKWebEditorView *webEditor;  // NOT KVO-compliant


#pragma mark Tree

@property(nonatomic, copy) NSArray *childWebEditorItems;
@property(nonatomic, assign, readonly) WEKWebEditorItem *parentWebEditorItem;

- (BOOL)isDescendantOfWebEditorItem:(WEKWebEditorItem *)anItem;

- (void)addChildWebEditorItem:(WEKWebEditorItem *)controller;
- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem with:(WEKWebEditorItem *)newItem;
- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem withItems:(NSArray *)newItems;
- (void)removeFromParentWebEditorItem;

// Be sure to call super from these methods
- (void)itemWillMoveToParentWebEditorItem:(WEKWebEditorItem *)newParentItem; 
- (void)itemWillMoveToWebEditor:(WEKWebEditorView *)newWebEditor;
- (void)itemDidMoveToParentWebEditorItem;
- (void)itemDidMoveToWebEditor;

- (NSEnumerator *)enumerator;


#pragma mark Siblings
- (WEKWebEditorItem *)previousWebEditorItem;
- (WEKWebEditorItem *)nextWebEditorItem;


#pragma mark Selection

- (BOOL)isSelectable;   // convenience for -selectableDOMElement
- (DOMElement *)selectableDOMElement;   // default is nil. Subclass for more complexity, shouldn't worry about KVO
- (DOMRange *)selectableDOMRange;
- (BOOL)shouldTrySelectingInline;
- (unsigned int)resizingMask;

@property(nonatomic, getter=isSelected) BOOL selected;  // draw selection handles & outline when YES
@property(nonatomic, getter=isEditing) BOOL editing;    // draw outline when YES

- (void)updateToReflectSelection;
- (BOOL)allowsDirectAccessToWebViewWhenSelected;

- (NSArray *)selectableAncestors;   // Search up the tree for all parent items returning YES for -isSelectable
- (NSArray *)selectableTopLevelDescendants;


#pragma mark Searching the Tree
- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;  // like -[NSView hitTest:]
- (WEKWebEditorItem *)hitTestRepresentedObject:(id)object;


#pragma mark Editing
- (NSMenu *)menuForEvent:(NSEvent *)theEvent;


#pragma mark UI
- (NSArray *)contextMenuItemsForElement:(NSDictionary *)element
                       defaultMenuItems:(NSArray *)defaultMenuItems;


#pragma mark Drag Source
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag;


#pragma mark Moving
- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
- (void)moveEnded;
- (CGPoint)position;    // center point (for moving) in doc view coordinates


#pragma mark Resizing
- (unsigned int)resizingMask;   // default is 0
- (SVGraphicHandle)resizeUsingHandle:(SVGraphicHandle)handle event:(NSEvent *)event;
- (BOOL)shouldResizeInline; // Default is NO. If YES, cursor will be locked to match the resize


#pragma mark Layout

- (NSRect)boundingBox;  // like -[DOMNode boundingBox] but performs union with subcontroller boxes
- (NSRect)selectionFrame;

// Expressed in -HTMLElement's document view's coordinates. If overrding, generally call super and union your custom rect with that
- (NSRect)drawingRect;

- (KSSelectionBorder *)newSelectionBorder;


#pragma mark Display
- (void)setNeedsDisplay;    // shortcut to -[WEKWebEditorView setNeedsDisplayForItem:] 


#pragma mark Drawing
// dirtyRect is expressed in the view's co-ordinate system. view is not necessarily the context being drawn into (but generally is)
- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
- (void)displayRect:(NSRect)aRect inView:(NSView *)view;    // Calls -drawRect:… down the tree


#pragma mark Debugging
- (NSString *)descriptionWithIndent:(NSUInteger)level;
- (NSString *)blurb;


@end