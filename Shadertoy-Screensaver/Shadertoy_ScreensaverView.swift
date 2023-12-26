
//  Re-created in Swift by Anastasiy Safari on 12/25/23.
//  Created by Lauri Saikkonen on 14.7.2023.

import ScreenSaver
import Cocoa
import OpenGL.GL3


class Shadertoy_ScreensaverView: ScreenSaverView {
    
    
    var glView: NSOpenGLView?
    var openGLContext: NSOpenGLContext?
    var program: GLuint = 0
    var vertexArrayObject: GLuint = 0
    var vertexBufferObject: GLuint = 0
    var time: TimeInterval = 0.0
    var iFrame: Int = 0
    var configSheet: NSWindow?
    
    // TODO: Rename that
    static let MyModuleName = "com.Shadertoy-Screensaver"
    
    lazy var configurationWindowController: Shadertoy_ScreensaverConfigSheet = Shadertoy_ScreensaverConfigSheet(windowNibName: "Shadertoy_ScreensaverConfigSheet")
    
    override init?(frame: NSRect, isPreview: Bool) {
        
        super.init(frame: frame, isPreview: isPreview)
        
        let defaults = ScreenSaverDefaults(forModuleWithName: Shadertoy_ScreensaverView.MyModuleName)
        
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFADepthSize), 24,
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
            0
        ]
        
        let format = NSOpenGLPixelFormat(attributes: attrs)
        self.openGLContext = NSOpenGLContext(format: format!, share: nil)
        self.openGLContext?.view = self
        self.openGLContext?.makeCurrentContext()
        
        glView = NSOpenGLView(frame: NSZeroRect, pixelFormat: format)
        
        if glView == nil {
            print("Couldn't initialize OpenGL view.")
            return nil
        }
        
        self.addSubview(glView!)
        self.setUpOpenGL()
        
        self.program = glCreateProgram()
        
        let vertexShader = compileShader(type: GLenum(GL_VERTEX_SHADER), source: self.loadShader(name: "vertexshader.glsl")!)
        
        let header = Shadertoy_ScreensaverView.createShadertoyHeader()
        
        var shadertoyJson = defaults?.string(forKey: "ShaderJSON")
        
        // Temporary fix for empty json
        // TODO: Fix this in a better way - or it won't run draw() when shader is empty on start
        if shadertoyJson == nil {
            shadertoyJson = "111"
        }
        print("shadertoyJson \(String(describing: shadertoyJson))")
        
        var shaderInfo = self.JSONFromString(jsonString: shadertoyJson!)
        var shadertoyCode = ""
        var fragmentShaderString = ""
        var fragmentShader: GLuint = 0
        
        if shaderInfo["Error"] == nil {
            shadertoyCode = Shadertoy_ScreensaverView.getShaderStringFromJSON(shaderInfo: shaderInfo)
            
            // Temporary fix for empty json
            // TODO: Fix this in a better way - or it won't run draw() when shader is empty on start
            shadertoyCode = shadertoyCode.isEmpty ? "111" : shadertoyCode
            
            print("shadertoyCode: \(String(describing: shadertoyCode))")
            
            fragmentShaderString = header + shadertoyCode
            fragmentShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderString)
        }
        
        if fragmentShader == 0 {
            print("Error with fetched shader. Revert to shader loaded from disk")
            
            shaderInfo = Shadertoy_ScreensaverView.JSONFromFile(name: "shader.json")
            shadertoyCode = Shadertoy_ScreensaverView.getShaderStringFromJSON(shaderInfo: shaderInfo)
            
            fragmentShaderString = header + shadertoyCode
            fragmentShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderString)
        }
        
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)
        glLinkProgram(program)
        
        var success: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &success)
        if success == GL_FALSE {
            var infoLog = [GLchar](repeating: 0, count: 512)
            glGetProgramInfoLog(program, GLsizei(infoLog.count), nil, &infoLog)
            let infoLogString = String(cString: infoLog)
            print("Failed to link shader program: \(infoLogString)")
        }
        
        glUseProgram(program)
        
        var vbo: GLuint = 0
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glGenBuffers(1, &vbo)
        
        vertexArrayObject = vao
        vertexBufferObject = vbo
        
        print("Gl version: \(String(describing: String(cString: glGetString(GLenum(GL_VERSION)))))")
        
        // Higher framerates can result in GPU overheating
        // [self setAnimationTimeInterval:1/20.0]; // This should be set in the appropriate place in Swift
        print("Setup successful")
    }
    
    required init?(coder: NSCoder) {
        fatalError("### required init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        
        super.draw(dirtyRect)
        self.openGLContext?.makeCurrentContext()
        
        let vertices: [GLfloat] = [
            -1.0,  1.0,
             -1.0, -1.0,
             1.0, -1.0,
             1.0,  1.0
        ]
        
        glBindVertexArray(vertexArrayObject)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferObject)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GLfloat>.size * vertices.count, vertices, GLenum(GL_STATIC_DRAW))
        
        glClearColor(1.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        glUseProgram(program)
        
        glUniform1f(glGetUniformLocation(program, "iTime"), GLfloat(time))
        
        glUniform1f(glGetUniformLocation(program, "iFrame"), GLfloat(iFrame))
        glUniform1f(glGetUniformLocation(program, "iFrameRate"), GLfloat(1.0 / animationTimeInterval))
        glUniform1f(glGetUniformLocation(program, "iTimeDelta"), GLfloat(animationTimeInterval))
        
        let iResolutionLocation = glGetUniformLocation(program, "iResolution")
        
        var viewport = [GLint](repeating: 0, count: 4)
        glGetIntegerv(GLenum(GL_VIEWPORT), &viewport)
        let width = GLfloat(viewport[2])
        let height = GLfloat(viewport[3])
        
        glUniform3f(iResolutionLocation, width, height, 1.0)
        
        let posAttrib = GLuint(glGetAttribLocation(program, "position"))
        glVertexAttribPointer(posAttrib, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(posAttrib)
        
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4)
        glFlush()
        
        glDisableVertexAttribArray(posAttrib)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.openGLContext?.flushBuffer()
        self.openGLContext?.update()
    }
    
    func setUpOpenGL() {
        self.openGLContext?.makeCurrentContext()
        
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClearDepth(1.0)
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
    }
    
    
    func loadShaderAbsolutePath(_ path: String) -> String? {
        do {
            let shaderString = try String(contentsOfFile: path, encoding: .utf8)
            let bundle = Bundle(for: type(of: self))
            let resourceFiles = bundle.paths(forResourcesOfType: "glsl", inDirectory: nil)
            print("Resource files: \(resourceFiles)")
            print("Path: \(Bundle.main.resourcePath ?? "")")
            return shaderString
        } catch {
            print("Error loading shader: \(error.localizedDescription)")
            print("Shader path: \(path)")
            return nil
        }
    }
    
    
    func loadShader(name: String) -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: name, ofType: nil) else {
            print("Error: shader file \(name) not found.")
            return nil
        }
        
        do {
            let shaderString = try String(contentsOfFile: path, encoding: .utf8)
            return shaderString
        } catch {
            print("Error loading shader: \(error.localizedDescription)")
            print("Shader name: \(name)")
            print("Shader path: \(path)")
            return nil
        }
    }
    
    
    func compileShader(type: GLenum, source: String) -> GLuint {
        let shader = glCreateShader(type)
        var cSource = (source as NSString).utf8String
        glShaderSource(shader, 1, &cSource, nil)
        glCompileShader(shader)
        
        var status: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == GL_FALSE {
            var message = [GLchar](repeating: 0, count: 256)
            glGetShaderInfoLog(shader, GLsizei(message.count), nil, &message)
            let messageString = String(cString: message)
            print("Failed to compile shader: \(messageString)")
            return 0
        }
        
        return shader
    }
    
    
    override func animateOneFrame() {
        // Update time-based animations
        self.time += self.animationTimeInterval
        self.iFrame += 1
        
        self.needsDisplay = true
    }
    
    
    override var configureSheet: NSWindow? {
        return configurationWindowController.window
    }
    
    static func createShadertoyHeader() -> String {
        return """
        #version 410 core
        uniform vec3 iResolution;
        uniform float iTime;
        void mainImage(out vec4 c, in vec2 f);
        out vec4 shadertoy_out_color;
        void main(void) {
            vec4 color = vec4(1e20);
            mainImage(color, gl_FragCoord.xy);
            shadertoy_out_color = vec4(color.xyz, 1.0);
        }
        """
    }
    
    static func getShaderStringFromJSON(shaderInfo: [String: Any]) -> String {
        guard let shader = shaderInfo["Shader"] as? [String: Any],
              let renderPass = (shader["renderpass"] as? [[String: Any]])?.first,
              let code = renderPass["code"] as? String else {
            return ""
        }
        return code
    }
    
    static func JSONFromFile(name: String) -> [String: Any] {
        guard let path = Bundle(for: self).path(forResource: name, ofType: nil),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return [:]
        }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
    }
    
    func JSONFromString(jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            return [:]
        }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
    }
    
    
    override func startAnimation() {
        super.startAnimation()
    }
    
    override func stopAnimation() {
        super.stopAnimation()
    }
    
    override var isOpaque: Bool {
        return false
    }
    
    override var hasConfigureSheet: Bool {
        NSLog("######### hasConfigureSheet")
        return true
    }
    
}
