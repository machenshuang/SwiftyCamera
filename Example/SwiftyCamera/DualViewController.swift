//
//  DualViewController.swift
//  SwiftyCamera_Example
//
//  Created by 马陈爽 on 2024/7/2.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import UIKit
import SwiftyCamera
import SnapKit
import CoreMotion

class DualViewController: UIViewController {

    private var cameraManager: SYCameraManager!
    private var previewView: UIView!
    private var shutterBtn: UIButton!
    private var filpBtn: UIButton!
    private var albumBtn: UIButton!
    private var recordBtn: UIButton!
    private var cameraModeControl: UISegmentedControl!
    private var currentZoom: CGFloat = 0.0
    
    private var recordMode: SYRecordStatus = .recordNormal {
        didSet {
            refreshRecordUI()
        }
    }
    private var cameraMode: SYCameraMode = .photoMode {
        didSet {
            refreshCameraModeUI()
        }
    }
    
    private lazy var motion: CMMotionManager = {
       return CMMotionManager()
    }()
    
    private var isBacking: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        setup()
        cameraMode = .photoMode
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if cameraManager.isAuthority {
            cameraManager.startCapture()
            motion.motionStart { [weak self](orientation) in
                guard let `self` = self else {
                    return
                }
                self.cameraManager.deviceOrientation = orientation;
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if cameraManager.isAuthority {
            cameraManager.stopCapture()
            motion.motionStop()
        }
    }
    
    private func setup() {
        
        previewView = UIView(frame: .zero)
        previewView.backgroundColor = UIColor.white
        view.addSubview(previewView)
        let tapRecognzer = UITapGestureRecognizer(target: self, action: #selector(handleTapEvent(_:)))
        previewView.addGestureRecognizer(tapRecognzer)
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchEvent(_:)))
        previewView.addGestureRecognizer(pinchRecognizer)
        
        previewView.snp.makeConstraints {
            $0.width.equalToSuperview()
            $0.height.equalTo(661)
            $0.center.equalToSuperview()
        }
        
        let backView = UIView(frame: .zero)
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
        
        filpBtn = UIButton(frame: .zero)
        filpBtn.setImage(UIImage(named: "icon_filp"), for: .normal)
        filpBtn.addTarget(self, action: #selector(cameraFilp), for: .touchUpInside)
        view.addSubview(filpBtn)
        filpBtn.snp.makeConstraints {
            $0.width.height.equalTo(48)
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalTo(shutterBtn)
        }
        
        cameraModeControl = UISegmentedControl(items: [UIImage(named: "icon_photo_selector")!, UIImage(named: "icon_movie_selector")!])
        cameraModeControl.selectedSegmentIndex = 0
        cameraModeControl.addTarget(self, action: #selector(changeCameraMode(_:)), for: .valueChanged)
        view.addSubview(cameraModeControl)
        cameraModeControl.snp.makeConstraints {
            $0.bottom.equalTo(shutterBtn.snp.top).offset(-20)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(CGSize(width: 80, height: 40))
        }
        
        recordBtn = UIButton(type: .custom)
        recordBtn.setImage(UIImage(named: "icon_start_record"), for: .normal)
        recordBtn.addTarget(self, action: #selector(handleRecordEvent(_:)), for: .touchUpInside)
        view.addSubview(recordBtn)
        recordBtn.snp.makeConstraints {
            $0.edges.equalTo(shutterBtn)
        }
        
        cameraManager = SYCameraManager()
        self.requestVideoPermission { [weak self](ret) in
            guard let `self` = self else {
                return
            }
            guard ret else { return }
            self.requestAudioPermission { [weak self](ret) in
                guard let `self` = self else {
                    return
                }
                guard ret else { return }
                self.setupCamera()
            }
        }
    }
    
    private func requestVideoPermission(completion: @escaping (Bool)->Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (ret) in
                DispatchQueue.main.async {
                    completion(ret)
                }
                
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
            
        }
    }
    
    private func requestAudioPermission(completion: @escaping (Bool)->Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { (ret) in
                DispatchQueue.main.async {
                    completion(ret)
                }
                
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
            
        }
    }

    private func setupCamera() {
        let config = SYCameraConfig()
        config.mode = cameraMode
        config.type = .dualDevice
        
        cameraManager.requestCamera(with: config) { [weak self](ret) in
            guard let `self` = self else { return }
            if ret {
                self.cameraManager.delegate = self
                self.cameraManager.addPreview(to: self.previewView)
                self.cameraManager.startCapture()
            }
        }
    }
    
    private func refreshRecordUI() {
        if recordMode == .recordNormal {
            recordBtn.setImage(UIImage(named: "icon_start_record"), for: .normal)
            filpBtn.isHidden = false
        } else {
            recordBtn.setImage(UIImage(named: "icon_stop_record"), for: .normal)
            filpBtn.isHidden = true
        }
    }
    
    private func refreshCameraModeUI() {
        if cameraMode == .photoMode {
            recordBtn.isHidden = true
            shutterBtn.isHidden = false
            cameraModeControl.selectedSegmentIndex = 0
        } else if cameraMode == .videoMode {
            recordBtn.isHidden = false
            shutterBtn.isHidden = true
            cameraModeControl.selectedSegmentIndex = 1
        }
        
    }
    
    @objc private func takePhoto() {
        if !cameraManager.isAuthority {
            return
        }
        cameraManager.takePhoto()
    }
    
    @objc private func cameraFilp() {
        if cameraManager.isAuthority {
            isBacking = !isBacking
            cameraManager.changeCameraPosition(isBacking ? .back : .front)
        }
    }

    @objc private func changeCameraMode(_ control: UISegmentedControl) {
        if !cameraManager.isAuthority {
            return
        }
        if control.selectedSegmentIndex == 0 {
            cameraManager.changeCameraMode(.photoMode, withSessionPreset: nil)
        } else if control.selectedSegmentIndex == 1 {
            cameraManager.changeCameraMode(.videoMode, withSessionPreset: nil)
        }
    }
    
    @objc private func handleRecordEvent(_ button: UIButton) {
        if !cameraManager.isAuthority {
            return
        }
        if recordMode == .recordNormal {
            cameraManager.startRecord()
        } else {
            cameraManager.stopRecord()
        }
    }
    
    @objc private func handleTapEvent(_ sender: UITapGestureRecognizer) {
        if !cameraManager.isAuthority {
            return
        }
        let point = sender.location(in: previewView)
        cameraManager.focus(with: point, mode: .autoFocus)
        cameraManager.exposure(with: point, mode: .autoExpose)
    }
    
    @objc private func handlePinchEvent(_ sender: UIPinchGestureRecognizer) {
        
        if !cameraManager.isAuthority {
            return
        }
        
        let scale = sender.scale
        currentZoom = scale;
        cameraManager.setZoom(currentZoom, withAnimated: true)
    }

}

extension DualViewController: SYCameraManagerDelegate {
    func cameraDidStarted(_ manager: SYCameraManager) {
        
    }
    
    func cameraDidStoped(_ manager: SYCameraManager) {
        
    }
    
    func cameraDidFinishProcessingVideo(_ outputURL: URL?, with manager: SYCameraManager, withError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            guard let outputURL = outputURL else {
                return
            }
            
            PreviewViewController.show(with: ["videoUrl": outputURL], from: self)
        }
    }
    
    func cameraDidFinishProcessingPhoto(_ image: UIImage?, withMetaData metaData: [AnyHashable : Any]?, with manager: SYCameraManager, withError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            guard let image = image else {
                return
            }
            
            PreviewViewController.show(with: ["image": image], from: self)
        }
    }
    
    
    func cameraDidChange(_ mode: SYCameraMode, with manager: SYCameraManager) {
        DispatchQueue.main.async {
            self.cameraMode = mode
        }
        
    }
    
    func cameraRecordStatusDidChange(_ status: SYRecordStatus, with manager: SYCameraManager) {
        DispatchQueue.main.async {
            self.recordMode = status;
        }
    }
    
    func cameraDidChangedFocus(_ value: CGPoint, mode: AVCaptureDevice.FocusMode, with manager: SYCameraManager) {
        print("ViewController cameraDidChangedFocus value = \(value), mode = \(mode)")
    }
    
    func cameraDidChangedExposure(_ value: CGPoint, mode: AVCaptureDevice.ExposureMode, with manager: SYCameraManager) {
        print("ViewController cameraDidChangedExposure value = \(value), mode = \(mode)")
    }
    
    func cameraDidChangedZoom(_ value: CGFloat, with manager: SYCameraManager) {
        print("ViewController cameraDidChangedZoom value = \(value)")
    }
}
