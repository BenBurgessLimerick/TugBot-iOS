//
//  ViewController.swift
//  TugBot
//
//  Created by Ben Burgess-Limerick on 15/4/19.
//  Copyright © 2019 Ben Burgess-Limerick. All rights reserved.
//
import UIKit
import BRHJoyStickView
import RBSManager
import WebKit

class ViewController: UIViewController, UITextFieldDelegate, RBSManagerDelegate {
    @IBOutlet weak var linearSpeed: UISlider!
    @IBOutlet weak var angularSpeed: UISlider!
    
    @IBOutlet weak var hostAddressField: UITextField!
    @IBOutlet weak var connectBtn: UIButton!
    
    @IBOutlet weak var video: UIImageView!
    
    let joystickSpan: CGFloat = 200.0
    let joystickOffset: CGFloat = (UIScreen.main.bounds.width - 200.0) / 2
    
    var forwardSensitivity: Float = 1.0
    var angularSensitvity: Float = 1.0
    
    var desiredForwardVel: Float64 = 0.0
    var desiredAngularVel: Float64 = 0.0
    
    var joystick1: JoyStickView!
    
    // user settings
    var socketHost: String?
    
    // sending message timer
    var sendTimer: Timer?
    
    // RBSManager
    var rosManager: RBSManager?
    var velocityPublisher: RBSPublisher?
    
    @IBOutlet var webView: WKWebView!
    
    @IBAction func sliderChanged(_ sender: UISlider, forEvent event: UIEvent) {
        
        if (sender == linearSpeed) {
            forwardSensitivity = 2 * linearSpeed.value
//            print("Changed forward")
        } else if (sender == angularSpeed) {
            angularSensitvity = 5 * angularSpeed.value
//            print("Changed angular")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostAddressField.delegate = self
        
        rosManager = RBSManager.sharedManager()
        rosManager?.delegate = self
        
//        let videoSubscriber = rosManager?.addSubscriber(topic: "/raspicam_node/image/compressed", messageClass: CompressedImageMessage.self, response: { (message) -> (Void) in
//            // update the view with message data
//            self.updateVideoFrame(message as! CompressedImageMessage)
//        })
//        videoSubscriber?.messageType = "sensor_msgs/CompressedImage"
        
        velocityPublisher = rosManager?.addPublisher(topic: "/tugbot_velocity_controller/cmd_vel", messageType: "geometry_msgs/Twist", messageClass: TwistMessage.self)
        
        loadSettings()
        hostAddressField.text = socketHost
        
        let monitor: JoyStickViewMonitor = { angle, displacement in
            let angleRad = Float(angle) * (Float.pi / 180.0) // convert to rad
            let x = sinf(angleRad) * Float(displacement)
            let y = cosf(angleRad) * Float(displacement)
            
            self.desiredForwardVel = Float64(y * self.forwardSensitivity)
            self.desiredAngularVel = Float64(-x * self.angularSensitvity)
            
        }
        
        // Do any additional setup after loading the view, typically from a nib.
        joystick1 = makeJoystick(tintColor: UIColor.lightGray)
        joystick1.movable = false
        joystick1.travel = 1.0
        joystick1.handleSizeRatio = 0.8
        joystick1.accessibilityLabel = "joystick"
        joystick1.monitor = monitor
        
        sendTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(sendDesiredVelocity), userInfo: nil, repeats: true)
        
    }
    
    
//    func updateVideoFrame(_ message: CompressedImageMessage) {
//        print ("Received Image")
//        let imageData = message.data
//        if (imageData != nil) {
//            video.image = UIImage(data: Data(imageData!))
//        } else {
//            print("Was nil")
//        }
//    }
    
    @objc func sendDesiredVelocity() {
        
        let twistMsg = TwistMessage()
        let linear = twistMsg.linear
        let angular = twistMsg.angular
        linear!.x = desiredForwardVel
        angular!.z = desiredAngularVel
        velocityPublisher?.publish(twistMsg)
    }
        
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        socketHost = defaults.string(forKey: "socket_host")
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(socketHost, forKey: "socket_host")
    }
    
    private func makeJoystick(tintColor: UIColor) -> JoyStickView {
        let frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: joystickSpan, height: joystickSpan))
        let joystick = JoyStickView(frame: frame)
        
        view.addSubview(joystick)
        
        //joystick.monitor = .polar(monitor: monitor)
        joystick.alpha = 1.0
        joystick.baseAlpha = 0.75
        joystick.handleTintColor = tintColor
        joystick.colorFillHandleImage = false
        return joystick
    }
    
    private func repositionJoysticks(size: CGSize) {
        let span = joystickOffset + joystickSpan / 2.0
        let offset = CGSize(width: span, height: span)
        joystick1.center = CGPoint(x: offset.width, y: size.height - (1.0 * offset.height))
    }
    
    func manager(_ manager: RBSManager, threwError error: Error) {
        if (manager.connected == false) {
            
        }
        print(error.localizedDescription)
    }
    
    func manager(_ manager: RBSManager, didDisconnect error: Error?) {
        connectBtn.setTitle("Connect to TugBot", for: .normal)
        print("Disconnected!")
        
        //stop sending
        sendTimer?.invalidate()
        sendTimer = nil
        print(error?.localizedDescription ?? "connection did disconnect")
    }
    
    
    func managerDidConnect(_ manager: RBSManager) {
        print("Connected!")
        
        connectBtn.setTitle("Disconnect from TugBot", for: .normal)
        
        //start sending
        if sendTimer == nil {
            sendTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(sendDesiredVelocity), userInfo: nil, repeats: true)
        }
    }
    
    @IBAction func ConnectBtnPressed(_ sender: Any) {
        socketHost = hostAddressField.text
        if rosManager?.connected == true {
            rosManager?.disconnect()
        } else {
            if socketHost != nil {
                // the manager will produce a delegate error if the socket host is invalid
                let url = URL(string: "http://" + socketHost!.split(separator: ":")[0] + ":8000")!
                webView.load(URLRequest(url: url))
                
                rosManager?.connect(address: socketHost!)
                saveSettings()
            } else {
                // print log error
                print("Missing socket host value --> use host button")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        repositionJoysticks(size: view.bounds.size)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            
        }, completion: { _ in
            self.repositionJoysticks(size: size)
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

