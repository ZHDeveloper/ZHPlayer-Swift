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
    
    var player = ZHPlayer()

    var videos: [String] = [
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/29/e53432e64402162688700d9e79fd6b6d-854x480.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/28/d92065bdb0118b960c4852758c8eeffd-480x856.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/28/e13b67e74742c69b100b40bc2f3daf25-960x544.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/27/c97a1841ae52ecf3e95002c3b44ace58-640x360.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/27/2c5772b00e810807b1b4ad28e1fd381e-640x360.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/26/a0d9ace34454ad2c5d863ab9a1d3540c-320x568.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/25/8321a0728e3b197b6bd1f6ed7ce4e422-544x544.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/25/2e312254dd4d3cea8c5eb4f5bd863978-540x540.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/59d4f70437100a2afe0c9bead2321d6a-960x544.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/493d6b46d7e1b01fcdf13c09cab6ce6f-368x640.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/5aac82f3701d8fa7f55ec639bfebab56-400x400.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/669b4aa09611d9a1726b2c5b3c6a4b69-320x568.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/d218e4226f8cf4f575e14f8a843aafa8-640x320.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/3a7edc4cee059aba77c28ba7a44bc915-360x480.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/360ac11dbcf1e3a8651f4bedd1cbac23-368x640.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/7a0a00150408c1672ef45546046842f2-320x568.mp4",
        "http://ytcdn.66boss.com/data/yuetao/video/2017/12/24/4960c170cb551d9ead40909cd61a7673-325x568.mp4"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player.delegate = self
        
        player.url = videos.first.url
        
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
    
    func playerReady(_ player: ZHPlayer) {
        
        print("视频准备播放")
        
    }
    
    func playerPlaybackStateDidChange(_ player: ZHPlayer) {
        
        if player.playbackState == .fail {
            print(player.error!)
        }
        print(player.playbackState)
    }
    
    func playerBufferingStateDidChange(_ player: ZHPlayer) {
        print(player.bufferingState)
    }
    
    func playerBufferTimeDidChange(_ bufferTime: TimeInterval) {
        print("视频缓冲时间：\(bufferTime)")
    }
    
    func playerCurrentTimeDidChange(_ player: ZHPlayer) {
        
    }
    
    func playerPlaybackDidEnd(_ player: ZHPlayer) {
        print("视频播放结束")
    }

    
}




