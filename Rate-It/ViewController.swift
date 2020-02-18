//
//  ViewController.swift
//  Rate-It
//
//  Created by Anton Skopin on 27.08.2019.
//  Copyright © 2019 cuberto. All rights reserved.
//

import UIKit
import Toast

@available(iOS 12.0, *)
class ViewController: UIViewController {
    
    @IBOutlet private weak var leftEye: EyeView! {
        didSet {
            leftEye.mode = .left
        }
    }
    @IBOutlet private weak var rightEye: EyeView! {
        didSet {
            rightEye.mode = .right
        }
    }
    @IBOutlet private weak var bgView: BackgroundView!
    @IBOutlet private weak var mouthView: MouthView!
    @IBOutlet private weak var slider: UISlider! {
        didSet {
            slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
            slider.addTarget(self, action: #selector(endTracking), for: .touchUpOutside)
            slider.addTarget(self, action: #selector(endTracking), for: .touchUpInside)
            slider.setThumbImage(#imageLiteral(resourceName: "track"), for: .normal)
            slider.setMinimumTrackImage(#imageLiteral(resourceName: "sliderTrack"), for: .normal)
            slider.setMaximumTrackImage(#imageLiteral(resourceName: "sliderTrack"), for: .normal)
        }
    }
    @IBOutlet private weak var textValueView: TitleView!
    @IBOutlet private weak var faceContainer: UIView!
    private var shakeTimer: Timer?
    private let startState: Rate = .normal
    
    @IBOutlet weak var inputText: UITextField!
    
    let twitter = Twitter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textValueView.updateState(to: startState)
        slider.setValue(startState.keyTime, animated: false)
        sliderMoved(sender: slider)
        
        inputText.delegate = self
        textValueView.isHidden = true
    }
    
    private func startShaking() {
        guard shakeTimer == nil else {
            return
        }
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) {[weak self] (timer) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.faceContainer.shake(count: 7, amplitude: 3.5)
        }
    }
    
    private func stopShaking() {
        shakeTimer?.invalidate()
        shakeTimer = nil
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopShaking()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldShake && !isShaking {
            startShaking()
        }
    }
    
    private var normalizedProgress: Float {
        return (slider.value - slider.minimumValue) / (slider.maximumValue - slider.minimumValue)
    }
    
    private var targetState: Rate {
        return Rate.allCases.reduce((.bad, Float.greatestFiniteMagnitude)) { (acc, state) -> (Rate, Float) in
            let diff = abs(normalizedProgress - state.keyTime)
            if  diff < abs(acc.1) {
                return (state, diff)
            }
            return acc
        }.0
    }
    
    private var shouldShake: Bool {
        return targetState == .bad
    }
    
    private var isShaking: Bool {
        return shakeTimer != nil
    }
    
    @objc private func sliderMoved(sender: UISlider) {
        let trackPoint = CGPoint(x: slider.frame.width * CGFloat(normalizedProgress), y: slider.frame.midY)
        [leftEye, rightEye, bgView, mouthView].forEach {
            $0?.progress = Double(normalizedProgress)
        }
        [leftEye, rightEye].forEach {
            $0?.track(to: $0?.convert(trackPoint, from: view), animated: ($0?.trackPoint == nil))
        }
        textValueView.animate(to: targetState)
        if shouldShake && !isShaking {
            startShaking()
        }
        if !shouldShake && isShaking {
            stopShaking()
        }
    }
    
    @objc private func endTracking() {
        [leftEye, rightEye].forEach {
            $0.track(to: nil, animated: true)
        }
        [leftEye, rightEye, bgView, mouthView].forEach {
            $0?.animate(to: targetState)
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.slider.setValue(self.targetState.keyTime, animated: true)
        })
    }
    
}

//
//  Extension
//  ViewController.swift
//  Rate-It
//
//  Created by Sergey Sevriugin on 17/02/2020.
//  Copyright © 2020 Sergei Sevriugin. All rights reserved.
//

@available(iOS 12.0, *)
extension ViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.alpha = 1
        
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print(textField.text ?? "?")
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField.text != "" {
            textField.alpha = 0.5
            return true
        } else {
            textField.placeholder = "You must type something"
            return false
        }
    }
    
    func setInput(enabled: Bool ) -> Void {
        inputText.isEnabled = enabled
        inputText.alpha = enabled ? 0.5 : 0.3
    }
    
    func setSlider(value: Float) -> Void {
        slider.setValue(value, animated: true)
        sliderMoved(sender: slider)
    }
    
    func makeToast(seach: String, score: Float?, total: Int?) -> Void {
        if let s = score, let t = total {
            DispatchQueue.main.async {
                self.view.makeToast("Score \(s) based \(t) tweets",
                    duration: 3.0,
                    position: .top,
                    title: seach )
            }
        } else {
            DispatchQueue.main.async {
                self.view.makeToast("Nothing found, try again later", duration: 3.0, position: .top, title: seach)
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if let seach = textField.text {
            
            print("Seach for \(seach)")
            
            self.setInput(enabled: false)
            self.textValueView.isHidden = false
            
            var count = 200
            var state: Float = 0.5
            
            // This is the call to get tweets and then predictions
            //      Initialy twitter.score and twitter.total are both set to nill(s)
            //      We will check score and total to became avalible in timer closure
            //      If score and totalare not ready within the 14 sec, we will show 'try later again message'
            self.twitter.score(q: seach)
            
            // Start timer to check score and total of tweets exctacted
            //      Show emotional changes during the wait period
            _ = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { timer in
                
                if let score = self.twitter.score, let total = self.twitter.total {
                    if self.slider.value == score {
                        
                        timer.invalidate()
                        
                        self.setInput(enabled: true)
                        
                        self.makeToast(seach: seach, score: score, total: total)
                        
                        return;
                    }
                }
                
                if count == 0 {
                    
                    timer.invalidate()
                    
                    self.setInput(enabled: true)
                    
                    if let score = self.twitter.score, let total = self.twitter.total {
                        
                        self.setSlider(value: score)
                        
                        self.makeToast(seach: seach, score: score, total: total)
                        
                    } else {
                        
                        self.makeToast(seach: seach, score: nil, total: nil)
                        
                    }
                    
                    return;
                    
                } else if count  >= 150 {
                    
                    state = Float(count - 150) / 100.0
                    
                } else if count >= 100 {
                    
                    state = 0.5 - (Float(count - 100) / 100.0)
                    
                } else if count >= 50 {
                    
                    state = 1 - (Float(count - 50) / 100.0)
                    
                } else {
                    
                    state = 0.5 + (Float(count) / 100.0)
                    
                }
                
                self.setSlider(value: state)
                count -= 1
            }
        }
    }
}
