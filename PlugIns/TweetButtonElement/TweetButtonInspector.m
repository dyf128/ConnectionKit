//
//  TweetButtonInspector.m
//  TweetButtonElement
//
//  Copyright (c) 2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "TweetButtonInspector.h"


static void *sTitleObservationContext = &sTitleObservationContext;
static void *sURLObservationContext = &sURLObservationContext;


@implementation TweetButtonInspector

- (void)awakeFromNib
{
    [self.inspectedPagesController addObserver:self 
                                    forKeyPath:@"selection.title"
                                       options:0 
                                       context:sTitleObservationContext];

    [self.inspectedPagesController addObserver:self 
                                    forKeyPath:@"selection.URL"
                                       options:0 
                                       context:sURLObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sTitleObservationContext)
    {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [self.inspectedPagesController valueForKeyPath:@"selection.title"], NSNullPlaceholderBindingOption,
                                 [NSNumber numberWithBool:YES], NSConditionallySetsEditableBindingOption,
                                 nil];
        [self.tweetTextField bind:@"value"
                         toObject:self
                      withKeyPath:@"inspectedObjectsController.selection.tweetText"
                          options:options];
    }
    else if (context == sURLObservationContext)
    {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [self valueForKeyPath:@"inspectedPagesController.selection.URL.svx_placeholderString"], NSNullPlaceholderBindingOption,
                                 [NSNumber numberWithBool:YES], NSConditionallySetsEditableBindingOption,
                                 nil];
        [self.tweetURLField bind:@"value"
                         toObject:self
                      withKeyPath:@"inspectedObjectsController.selection.tweetURL"
                          options:options];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc
{
    [self.inspectedPagesController removeObserver:self forKeyPath:@"selection.title"];
    [self.inspectedPagesController removeObserver:self forKeyPath:@"selection.URL"];
    self.inspectedPagesController = nil;
    
    [self.tweetTextField unbind:@"value"];
    self.tweetTextField = nil;
    
    [self.tweetURLField unbind:@"value"];
    self.tweetURLField = nil;
    
    [super dealloc];
}


@synthesize inspectedPagesController = _inspectedPagesController;
@synthesize tweetTextField = _tweetTextField;
@synthesize tweetURLField = _tweetURLField;
@end