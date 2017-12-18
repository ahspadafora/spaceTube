//
//  APIManager.swift
//  spaceTube
//
//  Created by Amber Spadafora on 12/14/17.
//  Copyright © 2017 Amber Spadafora. All rights reserved.
//

import Foundation

class APIManager {
    init(){}
    let session = URLSession(configuration: .default)
    
    func getApiData(from endpoint: URL, callback: @escaping ((Data?) -> Void)) {
        let request = URLRequest(url: endpoint, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            callback(data)
        }
        task.resume()
    }
    
    
}
