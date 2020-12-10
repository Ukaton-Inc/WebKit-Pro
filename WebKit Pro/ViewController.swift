import UIKit
import WebKit
import CoreMotion
import NearbyInteraction
import Speech

@available(iOS 14, *)
class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UITextFieldDelegate, CMHeadphoneMotionManagerDelegate, NISessionDelegate {
    
    // MARK: - WebKit
    private lazy var searchBarStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .fill
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 7
        stackView.backgroundColor = .clear
        stackView.clipsToBounds = true
        stackView.layer.cornerRadius = 10
        
        return stackView
    }()
    
    private lazy var searchTextField: PaddedTextField = {
        let textfield = PaddedTextField(frame: .zero)
        textfield.text = "https://webkit-pro.glitch.me/"
        textfield.translatesAutoresizingMaskIntoConstraints = false
        textfield.clipsToBounds = true
        textfield.layer.cornerRadius = 10
        textfield.backgroundColor = .lightText
        textfield.delegate = self
        textfield.placeholder = "Search"
        textfield.padding = 10
        textfield.autocorrectionType = .no
        
        return textfield
    }()
    
    private lazy var loadButton: UIButton = {
        let loadButton = UIButton(frame: .zero)
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        loadButton.addTarget(self, action: #selector(self.loadPage(_:)), for: .touchUpInside)
        loadButton.setTitle("Go", for: .normal)
        loadButton.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        loadButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        loadButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        loadButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        loadButton.layer.cornerRadius = 5
        loadButton.clipsToBounds = true
        loadButton.backgroundColor = .white
        loadButton.setTitleColor(.systemBlue, for: .normal)
        
        return loadButton
        
    }()
        
    private lazy var webView: WKWebView = {
        let contentController = WKUserContentController();
        contentController.add(self, name: "webkitpro")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true
        configuration.dataDetectorTypes = .all
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        return webView
    }()
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if webView != self.webView {
            decisionHandler(.allow, preferences)
            return
        }
        
        let app = UIApplication.shared
        if let url = navigationAction.request.url {
            // handle target="_blank"
            if navigationAction.targetFrame == nil {
                if app.canOpenURL(url) {
                    app.openURL(url)
                    decisionHandler(.cancel, preferences)
                    return
                }
            }
        // handle phone and email links
            if url.scheme == "tel" || url.scheme == "mailto" || url.scheme == "sms" {
                if app.canOpenURL(url) {
                    app.openURL(url)
                    decisionHandler(.cancel, preferences)
                    return
                }
            }
            decisionHandler(.allow, preferences)
        }
    }
    
    // MARK: - CoreMotion
    var motionManager: CMHeadphoneMotionManager!
    var startedHeadphoneMotion : Bool = false
    var didSetupHeadphoneMotion: Bool = false
    
    // MARK: - Nearby Interaction
    var nearbyInteractionSessions: [String: NISession] = [:]
        
    // MARK: - Speech
    let speechRecognizer = SFSpeechRecognizer()!
    var isSpeechRecognitionAuthorized: Bool = false
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    var startedSpeechRecognition: Bool = false
    
    // MARK: - Default
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // WebKit
        webView.uiDelegate = self
        
        self.view.addSubview(self.webView)
        self.view.addSubview(self.searchBarStackView)
        self.searchBarStackView.addArrangedSubview(self.searchTextField)
        self.searchBarStackView.addArrangedSubview(self.loadButton)
        
        var constraints = [NSLayoutConstraint]()
        constraints += [
            // web view
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webView.topAnchor.constraint(equalTo: self.searchBarStackView.bottomAnchor, constant: 10),
            self.webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            // stack view
            self.searchTextField.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.75),
            self.searchBarStackView.topAnchor.constraint(equalTo: self.view.layoutMarginsGuide.topAnchor),
            self.searchBarStackView.leadingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.leadingAnchor),
            self.searchBarStackView.trailingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.trailingAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        // COREMOTION
        
        self.loadPage(self)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        // Stop Motion
        // End Sessions
    }
    
    // MARK: - WebKit
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? NSDictionary {
            
            if let type = body["type"] as? String {
                switch(type) {
                
                // COREMOTION
                case "startheadphonemotion":
                    self.startHeadphoneMotion()
                    break
                case "stopheadphonemotion":
                    self.stopHeadphoneMotion()
                    break
                
                    
                // NEARBY INTERACTION
                case "createnearbyinteractionsession":
                    if let id = body["id"] as? String {
                        self.createNearbyInteractionSession(id: id)
                    }
                    break
                case "receivednearbyinteractionsessiontoken":
                    if let id = body["id"] as? String, let tokenString = body["token"] as? String {
                        guard let data = Data(base64Encoded: tokenString) else { return  }
                        
                        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                            fatalError("Unexpectedly failed to decode discovery token.")
                        }
                        
                        self.receivedNEarbyInteractionSessionToken(id: id, token: token)
                    }
                    break
                case "invalidatenearbyinteractionsession":
                    if let id = body["id"] as? String {
                        self.invalidateNearbyInteractionSession(id: id)
                    }
                    break
                
                    
                // SPEECH
                case "startspeechrecognition":
                    try? self.startSpeechRecognition()
                    break
                case "stopspeechrecognition":
                    self.stopSpeechRecognition()
                    break
                
                // AVFOUNDATION
                // getting dual streams
                default:
                    break
                }
            }
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // handle where to navigate to
    }
    
    @objc func loadPage(_ sender: Any) {
        if let text = self.searchTextField.text, let url = URL(string: "\(text)") {
            self.stopHeadphoneMotion()
            
            self.webView.load(URLRequest(url: url))
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.loadPage(textField)
        return true
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
            completionHandler()
        }))

        self.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
            completionHandler(false)
        }))

        self.present(alertController, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }

        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in

            completionHandler(nil)

        }))

        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - CoreMotion
    func stopHeadphoneMotion() {
        if(!self.startedHeadphoneMotion) {
            self.startedHeadphoneMotion = true
        }
    }
    func startHeadphoneMotion() {
        if(self.startedHeadphoneMotion) {
            self.startedHeadphoneMotion = false
        }
    }
    
    // MARK: - Nearby Interaction
    func createNearbyInteractionSession(id: String) {
        if NISession.isSupported {
            let session: NISession = NISession()
            session.delegate = self
            self.nearbyInteractionSessions[id] = session
            
            guard let token = session.discoveryToken else {
                print("Could not get `discoveryToken` for the given session.")
                return
            }
            
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
                fatalError("Unexpectedly failed to encode discovery token.")
            }
            
            let tokenString = encodedData.base64EncodedString()
                        
            self.webView.evaluateJavaScript("""
                window.dispatchEvent(new CustomEvent('nearbyinteractiontoken', {
                    detail: {
                        id: "\(id)",
                        token: "\(tokenString)",
                    },
                }));
            """, completionHandler: nil)
        }
    }
    func receivedNEarbyInteractionSessionToken(id: String, token: NIDiscoveryToken) {
        if let session = self.nearbyInteractionSessions[id] {
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
        }
    }
    func invalidateNearbyInteractionSession(id: String) {
        if let nearbyInteractionSession = self.nearbyInteractionSessions[id] {
            nearbyInteractionSession.invalidate()
            self.nearbyInteractionSessions.removeValue(forKey: id)
        }
    }
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        var id: String = ""
        for key in self.nearbyInteractionSessions.keys {
            if self.nearbyInteractionSessions[key] == session {
                id = key
                break
            }
        }
        
        guard let nearbyObject = nearbyObjects.first else { return }
        
        var direction: String = "null"
        if nearbyObject.direction != nil {
            direction = """
                {
                    x: \(nearbyObject.direction?.x ?? 0),
                    y: \(nearbyObject.direction?.y ?? 0),
                    z: \(nearbyObject.direction?.z ?? 0),
                }
            """
        }
        
        let distance: Float = nearbyObject.distance ?? 0

        self.webView.evaluateJavaScript("""
            window.dispatchEvent(new CustomEvent('nisessionupdate', {
                detail: {
                    id: "\(id)",
                    direction: \(direction),
                    distance: \(distance),
                },
            }));
        """, completionHandler: nil)
    }
    
    
    // MARK: - Speech
    func startSpeechRecognition() throws {
        if !self.startedSpeechRecognition {
            if let recognitionTask = recognitionTask {
                recognitionTask.cancel()
                self.recognitionTask = nil
            }

            //let audioSession = AVAudioSession.sharedInstance()
            //try audioSession.setCategory(.record, mode: .measurement, options: [])
            //try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            recognitionRequest.shouldReportPartialResults = true
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
                guard let `self` = self else { return }

                var isFinal = false
                
                if let result = result {
                    isFinal = result.isFinal
                    self.webView.evaluateJavaScript("""
                        window.dispatchEvent(new CustomEvent("speechrecognitionresult", {
                            detail: {
                                formattedString: "\(result.bestTranscription.formattedString)",
                                isFinal: \(result.isFinal),
                            },
                        }));
                    """, completionHandler: nil)
                }

                if error != nil || isFinal {
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                }
            }

            let recordingFormat = self.audioEngine.inputNode.outputFormat(forBus: 0)
            self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
            }

            self.audioEngine.prepare()
            try? self.audioEngine.start()
            
            self.startedSpeechRecognition = true
        }
    }
    func stopSpeechRecognition() {
        if self.startedSpeechRecognition {
            self.audioEngine.stop()
            self.recognitionRequest?.endAudio()
            
            self.startedSpeechRecognition = false
        }
    }
    
    // MARK: - AVFOUNDATION
}
