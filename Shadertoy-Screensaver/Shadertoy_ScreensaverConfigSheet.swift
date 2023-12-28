//
//  Shadertoy_ScreensaverConfigSheet.swift
//  Shadertoy-Screensaver
//
//  Developed by Anastasiy Safari on 12/25/23.
//  Created by Lauri Saikkonen on 14.7.2023.
//

import Cocoa
import ScreenSaver

class Shadertoy_ScreensaverConfigSheet: NSWindowController {

  static let MyModuleName = Bundle.main.bundleIdentifier ?? "com.Shadertoy-Screensaver"

  // List of shader IDs
  @IBOutlet weak var shadertoyShaderIDTextField: NSTextField!
  // Shader API key
  @IBOutlet weak var shadertoyAPIKeyTextField: NSTextField!
  // Status of loading list of shaders
  @IBOutlet weak var statusTextField: NSTextField!
  // Checkbox to display a separate shader on separate screen/monitor
  @IBOutlet weak var separateScreensCheckbox: NSButton!
  // Shuffle shaders across screens
  @IBOutlet weak var randomizeEvery5Checkbox: NSButton!

  override func windowDidLoad() {
    super.windowDidLoad()

    let defaults = ScreenSaverDefaults(
      forModuleWithName: Shadertoy_ScreensaverConfigSheet.MyModuleName)
    let shadertoyShaderID = defaults?.string(forKey: "ShadertoyShaderID") ?? ""
    let shadertoyApiKey = defaults?.string(forKey: "ShadertoyApiKey") ?? ""
    let shaderJson = defaults?.string(forKey: "ShaderJSON") ?? ""
    let separateScreens = defaults?.bool(forKey: "separateScreens") ?? false
    let randomizeEvery5 = defaults?.bool(forKey: "randomizeEvery5") ?? false

    NSLog("shaderJson in configsheet \(shaderJson)")
    shadertoyShaderIDTextField.stringValue = shadertoyShaderID
    shadertoyAPIKeyTextField.stringValue = shadertoyApiKey
    separateScreensCheckbox.state = separateScreens ? .on : .off
    randomizeEvery5Checkbox.state = randomizeEvery5 ? .on : .off

    // Set up the outline view's data source and delegate
    // Enable in the future
    // outlineView.dataSource = self
    // outlineView.delegate = self
  }

  // Validate the shader string by compiling it
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
      NSLog("Shader Compilation Error: \(errorMessage)")
      return errorMessage
    }

    return nil
  }

  // Fetch the shader JSON from the Shadertoy API when clicked "Fetch" in the dialog
  @IBAction func doneButtonClicked(_ sender: Any) {
    let defaults = ScreenSaverDefaults(
      forModuleWithName: Shadertoy_ScreensaverConfigSheet.MyModuleName)

    let shaderIDs = shadertoyShaderIDTextField.stringValue.split(separator: ",").map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    let shadertoyApiKey = shadertoyAPIKeyTextField.stringValue
    defaults?.set(shaderIDs.joined(separator: ","), forKey: "ShadertoyShaderID")
    defaults?.set(shadertoyApiKey, forKey: "ShadertoyApiKey")

    var shadersArray = [[String: Any]]()

    let dispatchQueue = DispatchQueue(label: "shaderQueue", attributes: [])
    dispatchQueue.async {
      var hasErrorOccurred = false

      for shaderID in shaderIDs {
        guard !hasErrorOccurred else { break }

        let requestUrl = self.createRequestString(shaderID: shaderID, apiKey: shadertoyApiKey)
        let semaphore = DispatchSemaphore(value: 0)

        self.fetchData(
          completion: { data, error, response in
            DispatchQueue.main.async {
              guard let data = data, error == nil, response.statusCode == 200 else {
                self.statusTextField.stringValue = "Error fetching shader for ID: \(shaderID)"
                hasErrorOccurred = true
                semaphore.signal()
                return
              }

              if let shaderJson = try? JSONSerialization.jsonObject(with: data, options: []),
                let jsonDictionary = shaderJson as? [String: Any]
              {
                if let errorMessage = jsonDictionary["Error"] as? String {
                  self.showAlert(title: "Shader \(shaderID) error", message: errorMessage)
                  hasErrorOccurred = true
                } else if let errorMessageCompile = self.validateFragmentShader(
                  shaderString: Shadertoy_ScreensaverView.getShaderStringFromJSON(
                    shaderInfo: jsonDictionary))
                {
                  self.showAlert(title: "Shader \(shaderID) error", message: errorMessageCompile)
                  hasErrorOccurred = true
                } else {
                  shadersArray.append(jsonDictionary)
                }
              } else {
                self.statusTextField.stringValue =
                  "Invalid data received for shader ID: \(shaderID)"
                hasErrorOccurred = true
              }
              semaphore.signal()
            }
          }, fullURL: requestUrl)

        semaphore.wait()
      }

      DispatchQueue.main.async {
        if !hasErrorOccurred {
          if let shadersData = try? JSONSerialization.data(
            withJSONObject: shadersArray, options: []),
            let shadersString = String(data: shadersData, encoding: .utf8)
          {
            NSLog("### Saved shaderString \(shadersString)")
            defaults?.set(shadersString, forKey: "ShaderJSONs")
            self.statusTextField.stringValue = "All shaders processed successfully"
          }
        }
        defaults?.synchronize()
      }
    }
  }

  func showAlert(title: String, message: String) {
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = title
      alert.informativeText = message
      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }

  func createRequestString(shaderID: String, apiKey: String) -> String {
    let baseUrl = "https://www.shadertoy.com/api/v1/shaders/"
    let urlWithShader = baseUrl + shaderID
    let urlWithApiKey = urlWithShader + "?key=" + apiKey
    return urlWithApiKey
  }

  func fetchData(completion: @escaping (Data?, NSError?, HTTPURLResponse) -> Void, fullURL: String)
  {
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
      let defaults = ScreenSaverDefaults(
        forModuleWithName: Shadertoy_ScreensaverConfigSheet.MyModuleName)
      let separateScreens = separateScreensCheckbox.state == .on
      let randomizeEvery5 = randomizeEvery5Checkbox.state == .on

      defaults?.set(separateScreens, forKey: "separateScreens")
      defaults?.set(randomizeEvery5, forKey: "randomizeEvery5")
      defaults?.synchronize()

      window.sheetParent?.endSheet(window)
    }
  }

}
