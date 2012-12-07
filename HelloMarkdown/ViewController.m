//
//  ViewController.m
//  HelloMarkdown
//
//  Created by Gregory Wieber on 9/11/12.
//  Copyright (c) 2012 humblehacker.com. All rights reserved.
//

#import "ViewController.h"
#import "markdown_lib.h"
#import "markdown_peg.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleTap:)];
    [[self view]addGestureRecognizer:tap];
    
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc]init];

    // p

    UIFont *paragraphFont = [UIFont fontWithName:@"AvenirNext-Medium" size:15.0];
    NSMutableParagraphStyle* pParagraphStyle = [[NSMutableParagraphStyle alloc]init];
    
    pParagraphStyle.paragraphSpacing = 12;
    pParagraphStyle.paragraphSpacingBefore = 12;
    NSDictionary *pAttributes = @{
        NSFontAttributeName : paragraphFont,
        NSParagraphStyleAttributeName : pParagraphStyle,
    };
    
    [attributes setObject:pAttributes forKey:@(PARA)];

    // h1
    UIFont *h1Font = [UIFont fontWithName:@"AvenirNext-Bold" size:24.0];
    [attributes setObject:@{NSFontAttributeName : h1Font} forKey:@(H1)];

    // h2
    UIFont *h2Font = [UIFont fontWithName:@"AvenirNext-Bold" size:18.0];
    [attributes setObject:@{NSFontAttributeName : h2Font} forKey:@(H2)];

    // h3
    UIFont *h3Font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:17.0];
    [attributes setObject:@{NSFontAttributeName : h3Font} forKey:@(H3)];

    // em
    UIFont *emFont = [UIFont fontWithName:@"AvenirNext-MediumItalic" size:15.0];
    [attributes setObject:@{NSFontAttributeName : emFont} forKey:@(EMPH)];

    // strong
    UIFont *strongFont = [UIFont fontWithName:@"AvenirNext-Bold" size:15.0];
    [attributes setObject:@{NSFontAttributeName : strongFont} forKey:@(STRONG)];

    // ul
    NSMutableParagraphStyle* listParagraphStyle = [[NSMutableParagraphStyle alloc]init];
    listParagraphStyle.headIndent = 16.0;
    [attributes setObject:@{NSFontAttributeName : paragraphFont, NSParagraphStyleAttributeName : listParagraphStyle} forKey:@(BULLETLIST)];

    // li
    NSMutableParagraphStyle* listItemParagraphStyle = [[NSMutableParagraphStyle alloc]init];
    listItemParagraphStyle.headIndent = 16.0;
    [attributes setObject:@{NSFontAttributeName : paragraphFont, NSParagraphStyleAttributeName : listItemParagraphStyle} forKey:@(LISTITEM)];

    // a
    UIColor *linkColor = [UIColor blueColor];
    [attributes setObject:@{NSForegroundColorAttributeName : linkColor} forKey:@(LINK)];
    
    // blockquote
    NSMutableParagraphStyle* blockquoteParagraphStyle = [[NSMutableParagraphStyle alloc]init];
    blockquoteParagraphStyle.headIndent = 16.0;
    blockquoteParagraphStyle.tailIndent = 16.0;
    blockquoteParagraphStyle.firstLineHeadIndent = 16.0;
    [attributes setObject:@{NSFontAttributeName : [emFont fontWithSize:18.0], NSParagraphStyleAttributeName : blockquoteParagraphStyle} forKey:@(BLOCKQUOTE)];
    
    // verbatim (code)
    NSMutableParagraphStyle* verbatimParagraphStyle = [[NSMutableParagraphStyle alloc]init];
    verbatimParagraphStyle.headIndent = 12.0;
    verbatimParagraphStyle.firstLineHeadIndent = 12.0;
    UIFont *verbatimFont = [UIFont fontWithName:@"CourierNewPSMT" size:14.0];
    [attributes setObject:@{NSFontAttributeName : verbatimFont, NSParagraphStyleAttributeName : verbatimParagraphStyle} forKey:@(VERBATIM)];

    
    NSError* error;
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"README" ofType:@"markdown"];
    NSString* inputText = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];

    NSMutableAttributedString* attr_out = markdown_to_attr_string(inputText,0,attributes);

    self.string = attr_out;
    self.textView.attributedText = self.string;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Handling Links

-(void)handleTap:(UITapGestureRecognizer*)tap
{
    UITextRange *characterRange = [self.textView characterRangeAtPoint:[tap locationInView:self.textView]];
    NSInteger startOffset = [self.textView offsetFromPosition:self.textView.beginningOfDocument toPosition:characterRange.start];
    NSInteger endOffset = [self.textView offsetFromPosition:self.textView.beginningOfDocument toPosition:characterRange.end];
    NSRange offsetRange = NSMakeRange(startOffset, endOffset - startOffset);
    [self.string enumerateAttributesInRange:offsetRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSURL *link = [attrs objectForKey:@"attributedMarkdownURL"];
        if (link) {
            NSLog(@"%@",link);
            [[UIApplication sharedApplication] openURL:link];

        }
    }];
}

@end
