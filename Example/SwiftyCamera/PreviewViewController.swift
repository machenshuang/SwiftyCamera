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
    
    var image: UIImage?

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
        }
    }
    
    static func show(with params: [String: Any], from vc: UIViewController) {
        let target = PreviewViewController()
        target.image = params["image"] as? UIImage
        vc.navigationController?.pushViewController(target, animated: true)
    }

}
