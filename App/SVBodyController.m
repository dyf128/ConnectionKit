//
//  SVBodyController.m
//  Sandvox
//
//  Created by Mike on 23/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyController.h"

#import "SVBodyElement.h"

#import "NSArray+Karelia.h"


@implementation SVBodyController

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    // Arrange using the linked list
    NSArray *result = [NSArray arrayWithDoublyLinkedListObject:[objects lastObject]
                                            nextObjectSelector:@selector(nextElement)
                                        previousObjectSelector:@selector(previousElement)];
    
    return result;
}

- (NSArray *)automaticRearrangementKeyPaths
{
    NSArray *result = [NSArray arrayWithObjects:@"nextElement", @"previousElement", nil];
    
    NSArray *otherKeyPaths = [super automaticRearrangementKeyPaths];
    if ([otherKeyPaths count] > 0)
    {
        result = [result arrayByAddingObjectsFromArray:otherKeyPaths];
    }
    
    return result;
}

- (void)insertObject:(SVBodyElement *)element atArrangedObjectIndex:(NSUInteger)index
{
    [super insertObject:element atArrangedObjectIndex:index];
    
    // Also insert into linked list
    [element insertAfterElement:[[self arrangedObjects] objectAtIndex:(index - 1)]];
}

@end
