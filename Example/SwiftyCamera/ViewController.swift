//
//  ViewController.swift
//  SwiftyCamera
//
//  Created by chenshuangma@foxmail.com on 05/25/2024.
//  Copyright (c) 2024 chenshuangma@foxmail.com. All rights reserved.
//

import UIKit
import SwiftyCamera
import SnapKit

class ViewController: UIViewController {
    
    private var cameraManager: SYCameraManager!
    private var previewView: UIView!
    private var shutterBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if cameraManager.isAuthority {
            cameraManager.startCapture()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if cameraManager.isAuthority {
            cameraManager.stopCapture()
        }
    }
    
    private func setup() {
        
        previewView = UIView(frame: .zero)
        previewView.backgroundColor = UIColor.white
        view.addSubview(previewView)
        
        previewView.snp.makeConstraints {
            $0.width.equalToSuperview()
            $0.height.equalTo(661)
            $0.center.equalToSuperview()
        }
        
        var backView = UIView(frame: .zero)
        backView.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 0.57)
        previewView.addSubview(backView)
        
        backView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        shutterBtn = UIButton(type: .custom)
        shutterBtn.setImage(UIImage(named: "icon_shutter"), for: .normal)
        shutterBtn.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        view.addSubview(shutterBtn)
        
        shutterBtn.snp.makeConstraints {
            $0.width.height.equalTo(72)
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(previewView.snp.bottom).offset(-20)
        }
        
        cameraManager = SYCameraManager()
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (ret) in
                if ret {
                    self.setupCamera()
                }
            }
        case .authorized:
            self.setupCamera()
        default:
            break
            
        }
    }
    
    private func setupCamera() {
        cameraManager.requestCamera(with: SYCameraConfig()) { [weak self](ret) in
            guard let `self` = self else { return }
            if ret {
                self.cameraManager.delegate = self
                self.cameraManager.addPreview(to: self.previewView)
                self.cameraManager.startCapture()
            }
        }
    }
    
    @objc private func takePhoto() {
        if (cameraManager.isAuthority) {
            cameraManager.takePhoto()
        }
    }

}

extension ViewController: SYCameraManagerDelegate {
    func cameraDidStarted(_ manager: SYCameraManager, withError error: Error?) {
        debugPrint("ViewController cameraDidStarted error = \(String(describing: error))")
    }
    
    func cameraDidStoped(_ manager: SYCameraManager, withError error: Error?) {
        debugPrint("ViewController cameraDidStoped error = \(String(describing: error))")
    }
    
    func cameraDidFinishProcessingPhoto(_ image: UIImage?, withMetaData metaData: [AnyHashable : Any]?, with manager: SYCameraManager, withError error: Error?) {
        //debugPrint("cameraDidFinishProcessingPhoto image = \(String(describing: image)), metaData = \(String(describing: metaData)), error = \(String(describing: error))")
    }
    
    
    
    
}

