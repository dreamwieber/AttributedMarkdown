//
//  ViewController.h
//  HelloMarkdown
//
//  Created by Gregory Wieber on 9/11/12.
//  Copyright (c) 2012 humblehacker.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) NSAttributedString *string;
@end
