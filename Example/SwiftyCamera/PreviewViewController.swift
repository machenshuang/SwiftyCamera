//
//  PreviewViewViewController.swift
//  SwiftyCamera_Example
//
//  Created by 马陈爽 on 2024/6/2.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import UIKit
import SnapKit

class PreviewViewController: UIViewController {
    
    private lazy var imageView: UIImageView = {
        return UIImageView(frame: .zero)
    }()
    
    private lazy var videoView: VideoPlayerView = {
        return VideoPlayerView(withURL: nil, frame: .zero)
    }()
    
    var image: UIImage?
    var videoUrl: URL?

    override func viewDidLoad() {
        self.view.backgroundColor = .black
        super.viewDidLoad()
        if let image = image {
            view.addSubview(imageView)
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            imageView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
        } else if let videoUrl = videoUrl {
            view.addSubview(videoView)
            videoView.updateUrl(url: videoUrl)
            videoView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            videoView.play()
        }
    }
    
    static func show(with params: [String: Any], from vc: UIViewController) {
        let target = PreviewViewController()
        target.image = params["image"] as? UIImage
        target.videoUrl = params["videoUrl"] as? URL
        vc.navigationController?.pushViewController(target, animated: true)
    }

}
