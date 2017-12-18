//
//  ViewController.swift
//  spaceTube
//
//  Created by Amber Spadafora on 12/14/17.
//  Copyright © 2017 Amber Spadafora. All rights reserved.
//

import UIKit

struct Constants {
    static let segueId = "goToVideoPlayerVC"
}

class VideoGalleryController: UIViewController, UpdatedVideos {
    
    // MARK: - IBOutlets
    @IBOutlet weak var videoListTableView: UITableView!
    
    // MARK - Properties
    private var filteredVideos: [Video] = [] {
        didSet {
            DispatchQueue.main.async {
                self.videoListTableView.reloadData()
            }
        }
    }
    private var videoGetter: VideoGetter!
    
    // MARK: - Override Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.videoGetter = VideoGetter(delegate: self)
        videoListTableView.dataSource = self
        videoListTableView.delegate = self
        self.videoGetter.getVideosFromApi()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let video = sender as? Video,
            let destinationVc = segue.destination as? VideoPlayerViewController else { return }
        destinationVc.video = video
    }
    
    // MARK: - Helper Functions
    func updatedVideos() {
        guard self.videoGetter.videos.count > 0 else { return }
        self.videoGetter.videos.forEach { (video) in
            self.videoGetter.getVideoUrl(video: video, callback: { (videoUrls) in
                guard videoUrls.count > 0 else { return }
                video.videoUrls = videoUrls
                self.filteredVideos.append(video)
            })
        }
    }
}

extension VideoGalleryController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredVideos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.videoListTableView.dequeueReusableCell(withIdentifier: "videoCell", for: indexPath) as? VideoTableViewCell else { return UITableViewCell() }
        cell.titleLabel.text = self.filteredVideos[indexPath.row].title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = self.filteredVideos[indexPath.row]
        performSegue(withIdentifier: Constants.segueId, sender: video)
    }
}


