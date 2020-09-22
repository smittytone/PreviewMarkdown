//
//  ViewController.swift
//  SwiftyMarkdownExample
//
//  Created by Simon Fairbairn on 05/03/2016.
//  Copyright © 2016 Voyage Travel Apps. All rights reserved.
//

import UIKit
import SwiftyMarkdown

class ViewController: UIViewController {

	
	@IBOutlet weak var textField : UITextField!
	@IBOutlet weak var textView : UITextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	
		// This is to help debugging.
		reloadText(nil)
		
		self.textField.text = "Yo I'm a *single* line **string**. How do I look?"
	}
	
	@IBAction func processText( _ sender : UIButton? ) {
		guard let existentText = self.textField.text else {
			return
		}
		self.textView.attributedText = SwiftyMarkdown(string: existentText).attributedString()
	}
	
	@IBAction func reloadText( _ sender : UIButton? ) {
				
		self.textView.dataDetectorTypes = UIDataDetectorTypes.all
		
		if let url = Bundle.main.url(forResource: "example", withExtension: "md"), let md = SwiftyMarkdown(url: url) {
			md.h2.fontName = "AvenirNextCondensed-Bold"
			md.h2.color = UIColor.blue
			md.h2.alignment = .center
			
			md.code.fontName = "CourierNewPSMT"
			

			if #available(iOS 13.0, *) {
				md.strikethrough.color = .tertiaryLabel
			} else {
				md.strikethrough.color = .lightGray
			}
			
			md.blockquotes.fontStyle = .italic
		
			md.underlineLinks = true
			
			self.textView.attributedText = md.attributedString()

		} else {
			fatalError("Error loading file")
		}
	}
}

