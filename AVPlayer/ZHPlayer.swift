//
//  ZHPlayer.swift
//  FontDemo
//
//  Created by ZhiHua Shen on 2017/12/28.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVKit

@objc public protocol ZHPlayerDelegate: NSObjectProtocol {
    @objc optional func playerReady(_ player: ZHPlayer)
    @objc optional func playerPlaybackStateDidChange(_ player: ZHPlayer)
    @objc optional func playerBufferingStateDidChange(_ player: ZHPlayer)
    @objc optional func playerBufferTimeDidChange(_ bufferTime: TimeInterval)
    @objc optional func playerCurrentTimeDidChange(_ player: ZHPlayer)
    @objc optional func playerPlaybackDidEnd(_ player: ZHPlayer)
}

private extension ZHPlayer {
    struct PlayerKey {
        static let tracks = "tracks"
        static let playable = "playable"
        static let duration = "duration"
        static let rate = "rate"
        static let status = "status"
        static let emptyBuffer = "playbackBufferEmpty"
        static let keepUp = "playbackLikelyToKeepUp"
        static let loadedTime = "loadedTimeRanges"
    }
}

public class ZHPlayer: NSObject {
    
    public enum PlaybackState: String, CustomStringConvertible {
        case stopped,playing,pause,fail
        public var description: String {
            return self.rawValue
        }
    }
    
    public enum BufferingState: String, CustomStringConvertible {
        case unknown //初始化默认状态
        case playable //检查asset时,判断URL是否可播放
        case through //缓存完成,此状态下会自动播放，autoplay = true
        case stalled //正在缓冲,此状态下会自动暂停，autoplay = true
        public var description: String {
            return self.rawValue
        }
    }
    
    /// 代理
    public weak var delegate: ZHPlayerDelegate?
    
    /// 视频的播放状态
    public var playbackState: ZHPlayer.PlaybackState = .stopped {
        didSet {
            guard playbackState != oldValue else { return }
            self.delegate?.playerPlaybackStateDidChange?(self)
        }
    }
    
    /// 缓冲状态改变
    public var bufferingState: ZHPlayer.BufferingState = .unknown {
        didSet {
            guard bufferingState != oldValue else { return }
            self.delegate?.playerBufferingStateDidChange?(self)
        }
    }

    /// 播放地址
    public var url: URL? {
        didSet {
            guard let url = url else { return }
            validateAsset(AVAsset(url: url))
        }
    }
    
    /// 播放器视图
    public let view = ZHPlayerView(frame: CGRect.zero)
    
    /// 自定播放
    public var autoplay: Bool = true
    
    /// 失去焦点时暂停
    public var pausesWhenResigningActive: Bool = true
    
    /// 进入后台时暂停
    public var pausesWhenBackgrounded: Bool = true
    
    /// 获得焦点时播放
    public var resumesWhenBecameActive: Bool = true
    
    /// 进入前台时播放
    public var resumesWhenEnteringForeground: Bool = true
    
    /// 静音
    public var muted: Bool {
        get {
            return player.isMuted
        }
        set {
            player.isMuted = newValue
        }
    }

    /// 音量
    public var volume: Float {
        get {
            return player.volume
        }
        set {
            player.volume = newValue
        }
    }
    
    /// 画面填充模式
    public var fillMode: AVLayerVideoGravity {
        get {
            return view.playerLayer.videoGravity
        }
        set {
            view.playerLayer.videoGravity = newValue
        }
    }

    /// 视频总时长
    public var duration: TimeInterval {
        get {
            guard let playerItem = player.currentItem else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
            return CMTimeGetSeconds(playerItem.duration)
        }
    }
    
    /// 当前视频播放时间
    public var currentTime: TimeInterval {
        get {
            guard let playerItem = player.currentItem else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
            return CMTimeGetSeconds(playerItem.currentTime())
        }
    }
    
    /// 视频的宽高
    public var naturalSize: CGSize {
        get {
            guard let playerItem = player.currentItem, let track = playerItem.asset.tracks(withMediaType: .video).first else {
                return .zero
            }
            let size = track.naturalSize.applying(track.preferredTransform)
            return CGSize(width: fabs(size.width), height: fabs(size.height))
        }
    }
    
    /// 视频的背景颜色,默认黑色
    public var layerBackgroundColor: UIColor = .black {
        didSet {
            view.layerColor = layerBackgroundColor
        }
    }
    
    /// 播放
    public func play() {
        guard let _ = player.currentItem else { return }
        guard playbackState != .playing else { return }
        playbackState = .playing
        player.play()
    }
    
    /// 暂停
    public func pause() {
        guard playbackState != .pause else { return }
        playbackState = .pause
        player.pause()
    }
    
    /// 停止播放
    public func stop() {
        guard playbackState != .stopped else { return }
        playbackState = .stopped
        player.pause()
        player.replaceCurrentItem(with: nil)
        url = nil
        error = nil
    }
    
    /// 快进
    public func seek(to time: CMTime, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        
        guard let playerItem = player.currentItem  else { return }
        
        bufferingState = .stalled
        
        playerItem.seek(to: time) { (finish) in
            if finish { self.bufferingState = .through }
            completionHandler?(finish)
        }
    }
    
    /// 视频截图
    public func takeSnapshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    /// 错误信息
    var error: Error?
    
    private let player = AVPlayer()
    
    private var _timeObserver: Any?
    
    public override init() {
        super.init()
        
        view.layerColor = layerBackgroundColor
        view.player = player

        addPlayerObservers()
        addApplicationObservers()
    }
    
    deinit {
        //移除定时器
        if _timeObserver != nil {
            player.removeTimeObserver(_timeObserver!)
            _timeObserver = nil
        }
        //移除观察者对象
        removeObservers()
        //移除通知
        NotificationCenter.default.removeObserver(self)
        
        print("ZHPlayer 销毁~")
    }
}

private extension ZHPlayer {
    
    func validateAsset(_ asset: AVAsset) {
        
        let keys = [PlayerKey.tracks, PlayerKey.playable, PlayerKey.duration]
        
        asset.loadValuesAsynchronously(forKeys: keys, completionHandler: { () -> Void in
            
            DispatchQueue.main.async {
                
                let deferror = NSError(domain: "Video resources are not available", code: 999, userInfo: [ NSLocalizedDescriptionKey : "Video resources are not available"])
                
                for key in keys {
                    var error: NSError? = nil
                    let status = asset.statusOfValue(forKey: key, error:&error)
                    if status == .failed {
                        self.error = error ?? deferror
                        self.playbackState = .fail
                    }
                }
                
                if !asset.isPlayable {
                    self.error = deferror
                    self.playbackState = .fail
                }
                else {
                    
                    self.error = nil
                    self.bufferingState = .playable
                    
                    self.removeObservers()
                    let playerItem = AVPlayerItem(asset:asset)
                    self.registerObservers(playerItem)
                    self.player.replaceCurrentItem(with: playerItem)
                }
            }
            
        })
    }
    
}

extension ZHPlayer {
    //处理观察监听
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath, let item = player.currentItem else { return }
        
        if keyPath == PlayerKey.keepUp {
            guard item.isPlaybackLikelyToKeepUp else { return }
            self.bufferingState = .through
            delegate?.playerBufferingStateDidChange?(self)
            guard autoplay else { return }
            player.play()
        }
        else if keyPath == PlayerKey.emptyBuffer {
            guard item.isPlaybackBufferEmpty else { return }
            self.bufferingState = .stalled
            delegate?.playerBufferingStateDidChange?(self)
            guard autoplay else { return }
            player.pause()
        }
        else if keyPath == PlayerKey.loadedTime {
            // 计算缓冲时间
            let timeRanges = item.loadedTimeRanges
            guard let timeRange = timeRanges.first?.timeRangeValue else { return }
            
            let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
            delegate?.playerBufferTimeDidChange?(bufferedTime)
        }
        else if keyPath == PlayerKey.status {
            
            switch player.status {
            case .failed:
                let deferror = NSError(domain: "Video play failed!", code: 1999, userInfo: [ NSLocalizedDescriptionKey : "Video play failed!"])
                self.error = player.error ?? deferror
                playbackState = .fail
                
            case .readyToPlay:
                delegate?.playerReady?(self)
                // 判断是否自动播放
                if autoplay {
                    play()
                }//判断缓冲状态
                if bufferingState == .playable {
                    bufferingState = .stalled
                }
                
            case .unknown:
                break
            }
            
        }
    }
    
    //播放结束通知
    @objc private func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        playbackState = .stopped
        delegate?.playerPlaybackDidEnd?(self)
    }
    
    //播放失败
    @objc private func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        error = NSError(domain: "Player failed to play to end time!", code: 1999, userInfo: [ NSLocalizedDescriptionKey : "Player failed to play to end time!"])
        playbackState = .fail
    }
}

// MARK: - Observer & Notification
private extension ZHPlayer {
    
    /// 监听视频的当前时间
    func addPlayerObservers() {
        self._timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 2), queue: DispatchQueue.main, using: { [weak self] timeInterval in
            guard let this = self else { return }
            this.delegate?.playerCurrentTimeDidChange?(this)
        })
    }
    
    /// 注册监听
    func registerObservers(_ playerItem: AVPlayerItem) {
        
        playerItem.addObserver(self, forKeyPath: PlayerKey.emptyBuffer, options: [.new, .old], context: nil)
        playerItem.addObserver(self, forKeyPath: PlayerKey.keepUp, options: [.new, .old], context: nil)
        playerItem.addObserver(self, forKeyPath: PlayerKey.status, options: [.new, .old], context: nil)
        playerItem.addObserver(self, forKeyPath: PlayerKey.loadedTime, options: [.new, .old], context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        
    }
    
    /// 移除监听
    func removeObservers() {
        
        guard let playerItem = player.currentItem else { return }
        
        playerItem.removeObserver(self, forKeyPath: PlayerKey.emptyBuffer, context: nil)
        playerItem.removeObserver(self, forKeyPath: PlayerKey.keepUp, context: nil)
        playerItem.removeObserver(self, forKeyPath: PlayerKey.status, context: nil)
        playerItem.removeObserver(self, forKeyPath: PlayerKey.loadedTime, context: nil)
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    /// 系统时间监听
    func addApplicationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: .UIApplicationWillResignActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object: UIApplication.shared)
    }
    
    @objc func handleApplicationWillResignActive(_ aNotification: Notification) {

        guard self.playbackState == .playing && self.pausesWhenResigningActive else { return }
        
        self.pause()
    }
    
    @objc func handleApplicationDidBecomeActive(_ aNotification: Notification) {
        
        guard self.playbackState != .playing && self.resumesWhenBecameActive else { return }
        
        self.play()
    }
    
    @objc func handleApplicationDidEnterBackground(_ aNotification: Notification) {
        
        guard self.playbackState == .playing && self.pausesWhenBackgrounded else { return }
        
        self.pause()
    }
    
    @objc func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        
        guard self.playbackState != .playing && self.resumesWhenEnteringForeground else { return }
        
        self.play()
    }
    
}

public class ZHPlayerView: UIView {
    
    override public class var layerClass: Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
    
    public var playerLayer: AVPlayerLayer {
        get {
            return layer as! AVPlayerLayer
        }
    }
    
    public var layerColor: UIColor? {
        get {
            guard let cgColor = playerLayer.backgroundColor else { return nil }
            return  UIColor(cgColor: cgColor)
        }
        set {
            guard let value = newValue else { return }
            playerLayer.backgroundColor = value.cgColor
        }
    }
    
    public var player: AVPlayer? {
        get {
            return self.playerLayer.player
        }
        set {
            self.playerLayer.player = newValue
        }
    }
    
}

