//
//  Shadertoy_ScreensaverConfigSheet.swift
//  Shadertoy-Screensaver
//
//  Re-created in Swift by Anastasiy Safari on 12/25/23.
//  Created by Lauri Saikkonen on 14.7.2023.
//

import Cocoa
import ScreenSaver

class Shadertoy_ScreensaverConfigSheet: NSWindowController {
    
    static let MyModuleName = "asafari.Shadertoy-Screensaver"
        
    @IBOutlet weak var shadertoyShaderIDTextField: NSTextField!
    @IBOutlet weak var shadertoyAPIKeyTextField: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!

    override func windowDidLoad() {
            super.windowDidLoad()
            
            let defaults = ScreenSaverDefaults(forModuleWithName: Shadertoy_ScreensaverConfigSheet.MyModuleName)
            let shadertoyShaderID = defaults?.string(forKey: "ShadertoyShaderID") ?? ""
            let shadertoyApiKey = defaults?.string(forKey: "ShadertoyApiKey") ?? ""
            let shaderJson = defaults?.string(forKey: "ShaderJSON") ?? ""
            print("shaderJson in configsheet \(shaderJson)")
            shadertoyShaderIDTextField.stringValue = shadertoyShaderID
            shadertoyAPIKeyTextField.stringValue = shadertoyApiKey
            
            // Set up the outline view's data source and delegate
            // Enable in the future
            // outlineView.dataSource = self
            // outlineView.delegate = self
        }
    
    
    
    func validateFragmentShader(shaderString: String) -> String? {
        let fullShaderString = Shadertoy_ScreensaverView.createShadertoyHeader() + shaderString

        let shader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
        var cSource = (fullShaderString as NSString).utf8String
        glShaderSource(shader, 1, &cSource, nil)
        glCompileShader(shader)

        var compileSuccess: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileSuccess)
        if compileSuccess == GL_FALSE {
            var messages = [GLchar](repeating: 0, count: 256)
            glGetShaderInfoLog(shader, GLsizei(messages.count), nil, &messages)
            let errorMessage = String(cString: messages)
            print("Shader Compilation Error: \(errorMessage)")
            return errorMessage
        }

        return nil
    }
    
    
    @IBAction func doneButtonClicked(_ sender: Any) {
        let defaults = ScreenSaverDefaults(forModuleWithName: Shadertoy_ScreensaverConfigSheet.MyModuleName)

        let currentShaderID = shadertoyShaderIDTextField.stringValue
        defaults?.set(currentShaderID, forKey: "ShadertoyShaderID")

        let currentApiKey = shadertoyAPIKeyTextField.stringValue
        defaults?.set(currentApiKey, forKey: "ShadertoyApiKey")

        let requestUrl = createRequestString(shaderID: currentShaderID, apiKey: currentApiKey)

        statusTextField.stringValue = "Fetching shader..."
        
        fetchData(completion: { data, error, response in
            DispatchQueue.main.async {
                guard let data = data, error == nil, response.statusCode == 200 else {
                    self.statusTextField.stringValue = "Error fetching shader"
                    return
                }

                self.statusTextField.stringValue = "Fetching shader was successful"

                if let shaderJson = String(data: data, encoding: .utf8) {
                    print("shaderJson: \(shaderJson)")

                    if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                       let jsonDictionary = jsonObject as? [String: Any] {
                        
                        if let errorMessage = jsonDictionary["Error"] as? String {
                            self.statusTextField.stringValue = "Invalid shader: \(errorMessage)"
                        } else {
                            if let errorMessageCompile = self.validateFragmentShader(shaderString: Shadertoy_ScreensaverView.getShaderStringFromJSON(shaderInfo: jsonDictionary)) {
                                self.statusTextField.stringValue = "Couldn't compile shader: \(errorMessageCompile)"

                                let alert = NSAlert()
                                alert.messageText = "Couldn't compile shader"

                                // Create a scrollable NSTextView
                                let scrollTextView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
                                scrollTextView.hasVerticalScroller = true
                                scrollTextView.borderType = .bezelBorder

                                let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 290, height: 190))
                                textView.isEditable = false
                                textView.string = errorMessageCompile
                                scrollTextView.documentView = textView

                                // Add the text view to the alert
                                alert.accessoryView = scrollTextView

                                // Display the alert
                                alert.runModal()

                            } else {
                                defaults?.set(shaderJson, forKey: "ShaderJSON")
                                defaults?.synchronize()
                            }
                        }
                    } else {
                        self.statusTextField.stringValue = "Invalid data received from Shadertoy"
                    }
                } else {
                    self.statusTextField.stringValue = "Error processing shader data"
                }
            }
        }, fullURL: requestUrl)

        defaults?.synchronize()
    }

    func createRequestString(shaderID: String, apiKey: String) -> String {
        let baseUrl = "https://www.shadertoy.com/api/v1/shaders/"
        let urlWithShader = baseUrl + shaderID
        let urlWithApiKey = urlWithShader + "?key=" + apiKey
        return urlWithApiKey
    }

    func fetchData(completion: @escaping (Data?, NSError?, HTTPURLResponse) -> Void, fullURL: String) {
        guard let url = URL(string: fullURL) else { return }
        let request = URLRequest(url: url)
        let session = URLSession.shared

        let task = session.dataTask(with: request) { data, response, error in
            if let response = response as? HTTPURLResponse {
                completion(data, error as NSError?, response)
            }
        }
        task.resume()
    }
    
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        if let window = self.window {
                window.sheetParent?.endSheet(window)
            }
    }


}
