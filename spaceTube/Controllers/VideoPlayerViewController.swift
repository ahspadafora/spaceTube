//
//  VideoPlayerViewController.swift
//  spaceTube
//
//  Created by Amber Spadafora on 12/15/17.
//  Copyright © 2017 Amber Spadafora. All rights reserved.
//

import AVFoundation
import UIKit

class VideoPlayerViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var playPauseBttn: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var videoTimeSlider: UISlider!
    @IBOutlet weak var videoActivityIndicator: UIActivityIndicatorView!

    // MARK: - Properties
    public var video: Video?
    private static var playerItemContext = 0
    private var isSeekInProgress = false
    private var chaseTime = kCMTimeZero
    private var videoUrl: URL?
    private let avPlayer = AVPlayer()
    private var avPlayerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?
    private var asset: AVAsset?
    private var timeObserverToken: Any?

    // MARK: - Computed Properties
    private var currentTime: Double {
        get {
            return CMTimeGetSeconds(avPlayer.currentTime())
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            avPlayer.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    private var duration: Double {
        guard let currentItem = avPlayer.currentItem else { return 0.0 }
        return CMTimeGetSeconds(currentItem.duration)
    }
    private var rate: Float {
        get {
            return avPlayer.rate
        }
        set {
            avPlayer.rate = newValue
        }
    }
    private let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
    // MARK: - Override Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.videoActivityIndicator.startAnimating()
        guard let video = self.video else {
            presentErrorAlert()
            return
        }
        self.title = video.title

        self.videoTimeSlider.isEnabled = false

        let mobileVideoString = video.videoUrls.first { string -> Bool in
            string.contains("mobile")
        }

        guard let vidUrlString = mobileVideoString,
            let videoUrl = URL(string: vidUrlString) else { return }

        prepareVideo(url: videoUrl)
        view.layer.insertSublayer(avPlayerLayer!, at: 0)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        avPlayerLayer?.frame = CGRect(x: 0, y: 40, width: view.bounds.width, height: view.bounds.height - 96.0)
    }

    override func viewDidDisappear(_ animated: Bool) {
        removeObservers()
        removePeriodicTimeObserver()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {

        guard context == &VideoPlayerViewController.playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        // called when AVPlayerItem status is updated
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus
            // get current statue of AVPlayer
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            switch status {
            case .readyToPlay:
                videoFinishedLoadingSetUp()
            case .failed:
                presentErrorAlert()
            case .unknown:
                return
            }
        // called when AVPlayer's current item's duration is updated
        } else if keyPath == #keyPath(AVPlayer.currentItem.duration) {
            let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            } else {
                newDuration = kCMTimeZero
            }
            // check the new duration is valid & does not equal 0, then format for slider and label
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            let currentTime = hasValidDuration ? Float(CMTimeGetSeconds(avPlayer.currentTime())) : 0.0

            // updated video slider & duration label
            videoTimeSlider.maximumValue = Float(newDurationSeconds)
            videoTimeSlider.value = currentTime
            durationLabel.text = createTimeString(time: Float(newDurationSeconds))
        }
    }

    // MARK: - IBAction Methods
    @IBAction func videoSliderChanged(_ sender: UISlider) {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: Double(sender.value), preferredTimescale: timeScale)
        stopPlayingAndSeekSmoothlyToTime(newChaseTime: time)
    }

    @IBAction func startStopVideo(_ sender: UIButton) {
        if avPlayer.rate > 0 {
            avPlayer.pause()
            playPauseBttn.setImage(UIImage(named: "play"), for: .normal)
        } else {
            if currentTime == duration {
                currentTime = 0.0
            }
            avPlayer.play()
            playPauseBttn.setImage(UIImage(named: "pause"), for: .normal)
        }
    }
    // MARK: - Forward/Rewind Methods
    func stopPlayingAndSeekSmoothlyToTime(newChaseTime: CMTime) {
        avPlayer.pause()
        playPauseBttn.setImage(UIImage(named: "play"), for: .normal)
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime
            if !isSeekInProgress {
                seekToTime()
            }
        }
    }

    func seekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        avPlayer.seek(to: seekTimeInProgress, toleranceBefore: kCMTimeZero,
                          toleranceAfter: kCMTimeZero, completionHandler: { (isFinished: Bool) -> Void in
                if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                    self.isSeekInProgress = false
                } else {
                    self.seekToTime()
                }
        })
    }

    // MARK: - Helper Functions
    func presentErrorAlert() {
        let alert = UIAlertController(title: "Error", message: "There has been an error opening this video", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        self.present(alert, animated: false)
    }

    func prepareVideo(url: URL) {
        let assetKeys = [
            "playable",
            "hasProtectedContent"
        ]
        self.asset = AVAsset(url: url)
        self.playerItem = AVPlayerItem(asset: asset!, automaticallyLoadedAssetKeys: assetKeys)
        avPlayerLayer = AVPlayerLayer(player: avPlayer)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &VideoPlayerViewController.playerItemContext)
        avPlayer.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.duration), options: [.new, .initial], context: &VideoPlayerViewController.playerItemContext)
        avPlayer.replaceCurrentItem(with: playerItem)
    }

    func addPeriodicTimeObserver() {
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: time, queue: .main, using: { [weak self] time in
            let timeElapsed = Float(CMTimeGetSeconds(time))
            let duration = self?.avPlayer.currentItem?.duration ?? kCMTimeZero
            let timeRemaining = Float(CMTimeGetSeconds(duration)) - timeElapsed
            self?.videoTimeSlider.value = timeElapsed
            self?.currentTimeLabel.text = self?.createTimeString(time: timeElapsed)
            self?.durationLabel.text = self?.createTimeString(time: timeRemaining)
        })
    }

    func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            avPlayer.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    func removeObservers() {
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        avPlayer.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.duration))
    }

    func createTimeString(time: Float) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))

        return timeRemainingFormatter.string(from: components as DateComponents)!
    }

    func videoFinishedLoadingSetUp() {
        self.videoActivityIndicator.stopAnimating()
        self.addPeriodicTimeObserver()
        self.videoTimeSlider.isEnabled = true
    }
}
