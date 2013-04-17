AttributedMarkdown: Native Markdown Parsing on iOS
==================================================

>> Markdown is intended to be as easy-to-read and easy-to-write as is feasible.

-- [Daring Fireball](http://daringfireball.net/projects/markdown/)

This library takes [Markdown](http://daringfireball.net/projects/markdown/) formatted text and turns it into an [NSAttributedString](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSAttributedString_Class/Reference/Reference.html), suitable for rendering in native UIKit components on iOS 6 (UITextView, UILabel, etc). 

In short, this allows you to apply styling to Markdown without having to use UIWebView and HTML tags.

This project is based-upon / modifies a Cocoa fork of [peg markdown](https://github.com/humblehacker/peg-markdown/). 

### Usage:

    // start with a raw markdown string
    NSString *rawText = @"Hello, world. *This* is native Markdown.";

    // create a font attribute for emphasized text
    UIFont *emFont = [UIFont fontWithName:@"AvenirNext-MediumItalic" size:15.0];
    
    // create a color attribute for paragraph text
    UIColor *color = [UIColor purpleColor];

    // create a dictionary to hold your custom attributes for any Markdown types
    NSDictionary *attributes = @{
      @(EMPH): @{NSFontAttributeName : emFont,},
      @(PARA): @{NSForegroundColorAttributeName : color,}
    };
   
    // parse the markdown
    NSAttributedString *prettyText = markdown_to_attr_string(rawText,0,attributes);

    // assign it to a view object
    myTextView.attributedText = prettyText;



Check out the HelloMarkdown example app to see it in action.
     
### Easy Setup (BETA)

A Cocoapod Podspec file has been added that will allow you to do a pod install to get up and running quickly. Eventually we'll post it to the cocoapods repo. For now, here's what your podfile should look like:

    platform :ios
    pod 'AttributedMarkdown', :git => 'https://github.com/dreamwieber/AttributedMarkdown.git'
    
(The HelloMarkdown project hasn't been updated or tested against a cocoapod install. If you find any issues please let us know. This should work fine for your new project though.) 

### Requirements & Setup

If you don't want to do Cocoapods, you can build the library yourself. There are some dependencies, which have proven tricky for some. Unless you need/want to modify the parser, it's probably easier to go with Cocoapod install. 

AttributedMarkdown makes use of a parser-generator called [greg](https://github.com/nddrylliog/greg). This is included 
as a submodule, and you'll need to first run this from the command-line (from your project's root directory): 

    git submodule update --init --recursive
    
You'll also need to include the CoreText Framework in your project.
    
To use AttributedMarkdown in one of your projects, follow the standard Apple guidelines for 
[linking against a static library](http://developer.apple.com/library/ios/#technotes/iOSStaticLibraries/Articles/configuration.html#/apple_ref/doc/uid/TP40012554-CH3-SW2)

Finally, create a group in your project called "Headers" and copy these files into it: 

    markdown_lib.h
    markdown_peg.h 

Leave the option to copy the files into your project _unselected_. 

(Note that you don't have to call the group "Headers", this is simply a suggestion. The important bit is making sure the header references exist somewhere in your project.)

The import statements in your project, wherever you want to make use of the library (eg., in a View Controller) should look like:

    #import "markdown_lib.h"
    #import "markdown_peg.h"

### Basic Cascading Styles

AttributedMarkdown performs some very basic cascading styles, merging the string attributes of parent elements into child elements by extracting their font traits via CoreText. This allows for things like emphasized words within an h1 tag to be bold as well as italicized.  

### Performance

Although I have yet to perform any optimizations, parsing and display of markdown in a UITableView filled with many cells of long-form markdown sample text performs rather well. 

### Limitations

This is a work in progress. Some tags are not yet supported, like img, etc. 

## Credit

AttributedMarkdown was created by [Gregory Wieber](http://gregorywieber.com) and Jim Radford. It is based upon
[peg-markdown](https://github.com/jgm/peg-markdown).

## License

AttributedMarkdown is released under both the GPL and the MIT license; see LICENSE for details. 

### Peg-Markdown License

peg-markdown is written and maintained by John MacFarlane (jgm on github), with significant contributions by Ryan Tomayko (rtomayko). It is released under both the GPL and the MIT license; see LICENSE for details. peg-markdown was adapted for Cocoa by David Whetstone.
