//
//  VideoPlayerView.swift
//  marki
//
//  Created by 马陈爽 on 2023/10/18.
//  Copyright © 2023 marki. All rights reserved.
//

import UIKit
import AVFoundation

protocol VideoPlayerDelegate: NSObjectProtocol {
    func videoDidLoaded(_ container: VideoPlayerView, success: Bool)
    func videoDidPlayed(_ container: VideoPlayerView)
    func videoDidPaused(_ container: VideoPlayerView)
    func videoDidReplay(_ container: VideoPlayerView)
    func videoDidPlayToEndTime(_ container: VideoPlayerView)
    func videoChangedMute(_ container: VideoPlayerView, muted: Bool)
    func videoChangedProgress(_ container: VideoPlayerView, progress: Double, time: Int)
}

class VideoPlayerView: UIView {
    
    private(set) var url: URL?
    private var playerItem: AVPlayerItem?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    weak var delegate: VideoPlayerDelegate?
    
    private var resumePlay: Bool = false
    
    var videoSize: CGSize {
        if let videoTrack = playerItem?.asset.tracks(withMediaType: .video).first {
            let videoSize = videoTrack.naturalSize
            let transform = videoTrack.preferredTransform
            let transformedSize = videoSize.applying(transform)
            let videoWidth = abs(transformedSize.width)
            let videoHeight = abs(transformedSize.height)
                
            return CGSize(width: videoWidth, height: videoHeight)
        }
        return .zero
    }
    
    var playedDuration: Int? {
        if let player = player {
            let time = CMTimeGetSeconds(player.currentTime())
            if !time.isNaN {
                return Int(ceil(time))
            }
            return nil
        }
        return nil
    }
    
    var videoDuration: Int? {
        if let playerItem = playerItem {
            let time = CMTimeGetSeconds(playerItem.duration)
            if !time.isNaN {
                return Int(ceil(time))
            }
            return nil
        }
        return nil
    }
    
    init(withURL url: URL?, frame: CGRect) {
        self.url = url
        super.init(frame: frame)
        setup()
    }
    
    deinit {
        unregister()
        if let playerLayer = playerLayer {
            playerLayer.removeFromSuperlayer()
            self.playerLayer = nil
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        // 创建AVPlayerItem
        if let url = url {
            let asset = AVURLAsset(url: url)
            playerItem = AVPlayerItem(asset: asset)
            // 创建AVPlayer
            player = AVPlayer(playerItem: playerItem)
            register()
        }
        // 创建AVPlayerLayer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.videoGravity = .resizeAspectFill
        playerLayer!.frame = self.bounds
        self.layer.addSublayer(playerLayer!)
    }
    
    func updateUrl(url: URL?) {
        guard let url = url else {
            return
        }
        if let originUrl = self.url, originUrl.relativePath == url.relativePath {
            return
        }
        self.url = url
        unregister()
        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            playerLayer?.player = player
        } else {
            // 创建AVPlayer
            player?.replaceCurrentItem(with: playerItem)
        }
        register()
    }
    
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = playerLayer {
            playerLayer.frame = self.bounds
        }
        
    }
    
    func play() {
        guard let player = player else { return }
        self.resumePlay = true
        player.play()
       
    }
    
    func pause() {
        guard let player = player else { return }
        self.resumePlay = false
        player.pause()
    }
    
    func replay() {
        guard let player = player else { return }
        pause()
        player.seek(to: kCMTimeZero)
        play()
    }
    
    var isMute: Bool {
        set {
            guard let player = player else { return }
            player.isMuted = newValue
        }
        get {
            guard let player = player else { return false }
            return player.isMuted
        }
    }
    
    private var statusObs: NSKeyValueObservation?
    private var controlStatusObs: NSKeyValueObservation?
    private var timeObserver: Any?
    
    private func register() {
        guard let player = self.player else { return }
        
        statusObs = player.observe(\.status, changeHandler: { [weak self](_, change) in
            guard let `self` = self else { return }
            if player.status == .readyToPlay {
                self.delegate?.videoDidLoaded(self, success: true)
                player.isMuted = false
            } else {
                self.delegate?.videoDidLoaded(self, success: false)
            }
        })
        
        controlStatusObs = player.observe(\.timeControlStatus, changeHandler: { [weak self](_, change) in
            guard let `self` = self else { return }
            switch player.timeControlStatus {
            case .playing:
                self.delegate?.videoDidPlayed(self)
                self.delegate?.videoChangedMute(self, muted: player.isMuted)
            case .paused:
                self.delegate?.videoDidPaused(self)
            default:
                break
            }
        })
        
        
        let interval = CMTime(value: 1, timescale: 1) // 1秒
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] (time) in
            guard let self = self else { return }
            guard let playerItem = self.playerItem else { return }
            // 每次触发间隔内执行的闭包
            let currentTime = CMTimeGetSeconds(time)
            let totalTime = CMTimeGetSeconds(playerItem.duration)
            if !currentTime.isNaN && !totalTime.isNaN {
                let progress = currentTime / totalTime
                self.delegate?.videoChangedProgress(self, progress: progress, time:Int(ceil(currentTime)))
            }
            
        }
        
        // 播放结束
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: OperationQueue.main) { [weak self] (noti) in
            guard let `self` = self else {
                return
            }
            if self.resumePlay {
                self.replay()
            }
            self.delegate?.videoDidPlayToEndTime(self)
        }
    }
    
    private func unregister() {
        if let player = player {
            if let timeObserver = timeObserver {
                player.removeTimeObserver(timeObserver)
            }
            player.replaceCurrentItem(with: nil)
            self.player = nil
        }
        
        statusObs = nil
        controlStatusObs = nil
    }
}
