//: [Previous](@previous)

import Foundation
import SpriteKit
import PlaygroundSupport



class GameScene : SKScene {
	var str = "# Text\n## Speaker 1\nHello, **playground**. *I* don't want to be here, you know. *I* want to be somewhere else."
	override func didMove(to view: SKView) {
		
		let md = SwiftyMarkdown(string: str)
		md.h2.alignment = .center
		md.body.alignment = .center
		
		let label = SKLabelNode(attributedText: md.attributedString())
		label.position = CGPoint(x: 100, y: 100)
		label.numberOfLines = 0
		label.preferredMaxLayoutWidth = 400
		label.horizontalAlignmentMode = .left
		self.addChild(label)
	}
}


let view = SKView(frame: CGRect(x: 0, y: 0, width: 600, height: 500))
let scene = GameScene(size: view.frame.size)
scene.scaleMode = .aspectFit
view.presentScene(scene)
PlaygroundPage.current.liveView = view

//: [Next](@next)
