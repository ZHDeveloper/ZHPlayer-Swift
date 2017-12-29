//
//  ViewController.swift
//  AVPlayer
//
//  Created by ZhiHua Shen on 2017/7/19.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var contentView: UIView!
    
    var player: ZHPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player = ZHPlayer()
        player.delegate = self

        player.url = URL(string: "http://ytcdn.66boss.com/data/yuetao/video/2017/07/05/bf2d7f4f8e89a24c43287c37b862737e-640x640.mp4")
        
        contentView.addSubview(player.view)
        player.view.fillToSuperview()
    }

    
}


// MARK: - Action
extension ViewController {
    
    @IBAction func playAction(_ sender: Any) {
        player.play()
    }
    
    @IBAction func pauseAction(_ sender: Any) {
        player.pause()
    }
    
    @IBAction func snapshotAction(_ sender: Any) {
        imageView.image = player.takeSnapshot()
    }
    
    @IBAction func switchVideoAction(_ sender: Any) {
        player.url = URL(string: "http://ytcdn.66boss.com/data/yuetao/video/2017/07/17/94f95dc22facf835128ea7f83f40d370-640x1136.mp4")
    }
}


// MARK: - ZHPlayerDelegate
extension ViewController: ZHPlayerDelegate {
    
  
    
}




