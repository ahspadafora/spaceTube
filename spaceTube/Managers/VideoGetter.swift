//
//  VideoGetter.swift
//  spaceTube
//
//  Created by Amber Spadafora on 12/14/17.
//  Copyright © 2017 Amber Spadafora. All rights reserved.
//

import Foundation

protocol UpdatedVideos: class {
    func updatedVideos()
}

class Video {
    let title: String
    var href: URL?
    var videoUrls: [String]

    init(title: String, href: URL?, videoUrls: [String]) {
        self.title = title
        self.href = href
        self.videoUrls = videoUrls
    }
}

class VideoGetter {
    private var api = APIManager()
    public var videos: [Video] = [] {
        didSet {
            delegate?.updatedVideos()
        }
    }
    weak var delegate: UpdatedVideos?

    init(delegate: UpdatedVideos) {
        self.videos = []
        self.delegate = delegate
    }

    public func getVideosFromApi() {
        guard let endpoint = URL(string: "https://images-api.nasa.gov/search?q=mars&media_type=video") else {
            print("Couldn't get url from nasa api string")
            return
        }
        api.getApiData(from: endpoint) { data in
            guard let validData = data else { return }
            guard let videos = self.formatVideos(from: validData) else { return }
            self.videos = videos
        }
    }

    private func formatVideos(from data: Data) -> [Video]? {
        var videos: [Video] = []
        do {
            let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = jsonData as? [String: AnyObject],
                let collection = dict["collection"],
                let items = collection["items"] as? [[String: AnyObject]] else { return nil }
            for item in items {
                guard let data = item["data"] as? [[String: AnyObject]],
                    let infoDictionary = data.first else { return nil }

                let title: String = infoDictionary["title"] as? String ?? "Untitled"
                let hrefString = (item["href"] as? String)?.replacingOccurrences(of: " ", with: "") ?? ""

                // only append the video to videos if the "href" data (the endpoint to retreive videoUrls for particular video) is a valid URL
                if let validHrefUrl = URL(string: hrefString) {
                    let video = Video(title: title, href: validHrefUrl, videoUrls: [])
                    videos.append(video)
                }
            }
        } catch let error as NSError {
            print(error)
        }
        return videos
    }

    public func getVideoUrl(video: Video, callback: @escaping ([String]) -> Void) {
        guard let hrefEndpoint = video.href else { return }

        api.getApiData(from: hrefEndpoint, callback: { data in
            guard let validData = data else { return }
            do {
                guard let jsonData = try JSONSerialization.jsonObject(with: validData, options: []) as? [String] else { return }

                let videoUrls = jsonData.filter({ string -> Bool in
                    string.hasSuffix(".mp4")
                })
                callback(videoUrls)
            } catch let error as NSError {
                print(error.localizedDescription)
                return
            }
        })
    }

}
