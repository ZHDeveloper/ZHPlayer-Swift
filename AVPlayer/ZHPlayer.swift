//
//  ZHPlayer.swift
//  AVPlayer
//
//  Created by ZhiHua Shen on 2017/7/19.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVFoundation

public enum PlaybackState: Int, CustomStringConvertible {
    case stopped = 0
    case playing
    case paused
    case failed
    
    public var description: String {
        get {
            switch self {
            case .stopped:
                return "Stopped"
            case .playing:
                return "Playing"
            case .failed:
                return "Failed"
            case .paused:
                return "Paused"
            }
        }
    }
}

public enum BufferingState: Int, CustomStringConvertible {
    case unknown = 0
    case keepUp
    case stalled
    
    public var description: String {
        get {
            switch self {
            case .unknown:
                return "Unknown"
            case .keepUp:
                return "KeepUp"
            case .stalled:
                return "Stalled"
            }
        }
    }
}

@objc public protocol ZHPlayerDelegate: class {
    // 准备播放
    @objc optional func playerReadyToPlay(_ player: ZHPlayer)
    // 播放状态改变
    @objc optional func playerPlaybackStateDidChange(_ player: ZHPlayer)
    // 缓冲状态改变
    @objc optional func playerBufferingStateDidChange(_ player: ZHPlayer)
    // 播放结束
    @objc optional func playerDidPlayFinish(_ player: ZHPlayer, error: Error?)
    
    @objc optional func playerBufferTimeDidChange(_ player: ZHPlayer)
    
    @objc optional func playerPeriodicTimeDidChange(_ player: ZHPlayer)
}

public class ZHPlayer: NSObject {
    
    public weak var delegate: ZHPlayerDelegate?

    public var url: URL? {
        didSet {
            guard let url = url else { return }
            setup(url: url)
        }
    }
    
    public let view: ZHPlayerView = ZHPlayerView(frame: CGRect.zero)
    
    public var shouldAutoplay: Bool = true
    
    public var currentTime: TimeInterval {
        return CMTimeGetSeconds(player.currentTime())
    }
    
    public var duration: TimeInterval? {
        if let durationTime = playerItem?.duration {
            return CMTimeGetSeconds(durationTime)
        }
        return nil
    }
    
    public var playableDuration: TimeInterval? {
        
        guard let playerItem = player.currentItem else { return nil }
        
        let ranges = playerItem.loadedTimeRanges
        guard ranges.count > 0 else { return nil }
        
        let timeRange = ranges.first!.timeRangeValue
        let startSec = CMTimeGetSeconds(timeRange.start)
        let endSec = CMTimeGetSeconds(timeRange.end)
        
        return startSec + endSec
    }
    
    public var playbackState: PlaybackState = .stopped {
        didSet {
            if playbackState != oldValue {
                delegate?.playerPlaybackStateDidChange?(self)
            }
        }
    }
    
    public var bufferingState: BufferingState = .unknown {
        didSet {
            if bufferingState != oldValue {
                delegate?.playerBufferingStateDidChange?(self)
            }
        }
    }
    
    public var isPlaying: Bool {
        if player.currentItem != nil, player.rate != 0 {
            return true
        }
        return false
    }
    
    public var isMuted: Bool {
        get {
            return player.isMuted
        }
        set {
            player.isMuted = newValue
        }
    }
    
    public var volume: Float {
        get {
            return player.volume
        }
        set {
            player.volume = newValue
        }
    }
    
    public var fillMode: AVLayerVideoGravity {
        get {
            return view.playerLayer.videoGravity
        }
        set {
            view.playerLayer.videoGravity = newValue
        }
    }
    
    public var layerBackgroundColor: UIColor = .black {
        didSet {
            view.playerLayer.backgroundColor = layerBackgroundColor.cgColor
        }
    }
    
    public var snapshotImage: UIImage? {
        
        guard let playerAsset = playerAsset,let playerItem = playerItem else { return nil }
        
        let imageGenerator = AVAssetImageGenerator(asset: playerAsset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: playerItem.currentTime(), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    fileprivate var player: AVPlayer = AVPlayer()
    fileprivate var playerItem: AVPlayerItem?
    fileprivate var seekTime: CMTime?
    fileprivate var timeObserver: Any?
    fileprivate var playerAsset: AVAsset?

    fileprivate var isComplete: Bool = false
    
    public override init() {
        super.init()
        view.playerLayer.backgroundColor = layerBackgroundColor.cgColor
        player.actionAtItemEnd = .pause
        installPlayerObservers()
    }
    
    init(url: URL) {
        super.init()
        view.playerLayer.backgroundColor = layerBackgroundColor.cgColor
        player.actionAtItemEnd = .pause
        installPlayerObservers()
        setup(url: url)
    }
    
    deinit {
        player.pause()
        removePlayerObservers()
        removePlayerItemObservers()
        delegate = nil
    }
    
}


// MARK: - Action
public extension ZHPlayer {
    
    fileprivate func setup(url: URL) {
        if self.playbackState == .playing {
            player.pause()
        }
        configAsset(AVAsset(url: url))
    }
    
    fileprivate func configAsset(_ asset: AVAsset) {
        
        if self.playbackState == .playing {
            self.pause()
        }
        
        isComplete = false
        
        playerAsset = asset
    }
    
    fileprivate func configPlayerItem(_ item: AVPlayerItem) {
        
        removePlayerItemObservers()
        
        playerItem = item
        
        installPlayerItemObservers()
        
        player.replaceCurrentItem(with: item)
    }
    
    public func prepareToPlay() {
        
        let keys = [PlayerViewConstKey.kPlayerTracks,PlayerViewConstKey.kPlayerPlayable,PlayerViewConstKey.kPlayerDuration]
        
        guard let playerAsset = playerAsset else { return }
        
        playerAsset.loadValuesAsynchronously(forKeys: keys, completionHandler: {
            // Enum if error
            for key in keys {
                var error: NSError? = nil
                let status = playerAsset.statusOfValue(forKey: key, error:&error)
                if status == .failed {
                    self.playbackState = .failed
                    self.delegate?.playerDidPlayFinish?(self, error: error)
                    return
                }
            }
            if playerAsset.isPlayable {
                self.configPlayerItem(AVPlayerItem(asset: playerAsset))
            }
            else {
                self.playbackState = .failed

                let info = [NSLocalizedFailureReasonErrorKey: "Asset can't play"]
                let error = NSError(domain: "Asset Error", code: 501, userInfo: info)
                self.delegate?.playerDidPlayFinish?(self, error: error)
            }
        })
    }
    
    public func play() {
        if isComplete {
            isComplete = false
            seek(to: kCMTimeZero,completeHandler: nil)
        }
        player.play()
    }
    
    public func pause() {
        if playbackState != .playing { return }
        player.pause()
    }
    
    public func seek(to time: CMTime,completeHandler: (()->Void)? = nil) {
        guard let playerItem = player.currentItem  else { return }
        playerItem.seek(to: time) { (seeked) in
            completeHandler?()
        }
    }
    
}

fileprivate struct PlayerViewConstKey {
    
    static let kPlayerTracks = "tracks"
    static let kPlayerPlayable = "playable"
    static let kPlayerDuration = "duration"
    
    static let kPlayerRate = "rate"
    static let kPlayerEmptyBuffer = "playbackBufferEmpty"
    static let kPlayerKeepUp = "playbackLikelyToKeepUp"
    static let kPlayerStatus = "status"
    static let kPlayerLoadedTimeRanges = "loadedTimeRanges"
}

// MARK: - Observers
extension ZHPlayer {
    
    func installPlayerObservers() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 60), queue: DispatchQueue.main) {[weak self] (time) in
            guard let this = self else { return }
            this.delegate?.playerPeriodicTimeDidChange?(this)
        }
        player.addObserver(self, forKeyPath: PlayerViewConstKey.kPlayerRate, options: [.new, .old], context: nil)
    }
    
    func removePlayerObservers() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        player.removeObserver(self, forKeyPath: PlayerViewConstKey.kPlayerRate)
    }
    
    func installPlayerItemObservers() {
        
        playerItem?.addObserver(self, forKeyPath: PlayerViewConstKey.kPlayerEmptyBuffer, options: ([.new, .old]), context: nil)
        playerItem?.addObserver(self, forKeyPath: PlayerViewConstKey.kPlayerKeepUp, options: ([.new, .old]), context: nil)
        playerItem?.addObserver(self, forKeyPath: PlayerViewConstKey.kPlayerStatus, options: ([.new, .old]), context: nil)
        playerItem?.addObserver(self, forKeyPath: PlayerViewConstKey.kPlayerLoadedTimeRanges, options: ([.new, .old]), context: nil)
        
        if let playerItem = playerItem {
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }

    }
    
    func removePlayerItemObservers() {
        
        playerItem?.removeObserver(self, forKeyPath: PlayerViewConstKey.kPlayerEmptyBuffer, context: nil)
        playerItem?.removeObserver(self, forKeyPath: PlayerViewConstKey.kPlayerKeepUp, context: nil)
        playerItem?.removeObserver(self, forKeyPath: PlayerViewConstKey.kPlayerStatus, context: nil)
        playerItem?.removeObserver(self, forKeyPath: PlayerViewConstKey.kPlayerLoadedTimeRanges, context: nil)
        
        if let playerItem = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }

    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == PlayerViewConstKey.kPlayerKeepUp {
            guard let item = playerItem,item.isPlaybackLikelyToKeepUp else { return }
            bufferingState = .keepUp
        }
        else if keyPath == PlayerViewConstKey.kPlayerEmptyBuffer {
            guard let item = playerItem,item.isPlaybackBufferEmpty else { return }
            bufferingState = .stalled
        }
        else if keyPath == PlayerViewConstKey.kPlayerLoadedTimeRanges {
            delegate?.playerBufferTimeDidChange?(self)
        }
        else if keyPath == PlayerViewConstKey.kPlayerStatus {
            switch player.status {
                case .readyToPlay:
                    
                    delegate?.playerReadyToPlay?(self)
                    view.playerLayer.player = player
                    
                    guard shouldAutoplay else { return }
                    play()
                
                case .failed:
                    playbackState = .failed
                    delegate?.playerDidPlayFinish?(self, error: player.error)
                default:
                    break
            }
        }
        else if keyPath == PlayerViewConstKey.kPlayerRate {
            
            guard let url = url,isComplete == false else { return }
            
            if isPlaying {
                playbackState = .playing
            }
            else {
                guard let duration = duration else { return }
                
                if currentTime < duration,url == (playerAsset as? AVURLAsset)?.url {
                    playbackState = .paused
                }
                else {
                    playbackState = .stopped
                }
            }
            
        }
    }
    
    @objc fileprivate func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        if isComplete { return }
        isComplete = true
        delegate?.playerDidPlayFinish?(self, error: nil)
    }
    
    @objc fileprivate func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        playbackState = .failed
        delegate?.playerDidPlayFinish?(self, error: player.error)
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
    
    deinit {
        playerLayer.player?.pause()
        playerLayer.player = nil
    }
}
