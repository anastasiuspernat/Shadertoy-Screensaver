//
//  Shadertoy_ScreensaverConfigSheet.m
//  Shadertoy-Screensaver
//
//  Created by Lauri Saikkonen on 26.7.2023.
//

#import "Shadertoy_ScreensaverConfigSheet.h"
#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/gl3.h>
#import <Shadertoy_ScreensaverView.h>

@interface Shadertoy_ScreensaverConfigSheet ()

@end

@implementation Shadertoy_ScreensaverConfigSheet

static NSString * const MyModuleName = @"diracdrifter.Shadertoy-Screensaver";

- (void)windowDidLoad {
    [super windowDidLoad];
    

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSUserDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName];
    NSString *shadertoyShaderID = [defaults stringForKey:@"ShadertoyShaderID"];
    NSString *shadertoyApiKey = [defaults stringForKey:@"ShadertoyApiKey"];
    NSString *shaderJson = [defaults stringForKey:@"ShaderJSON"];
    NSLog(@"shaderJson in configsheet %@", shaderJson);
    [self.shadertoyShaderIDTextField setStringValue:shadertoyShaderID];
    [self.shadertoyAPIKeyTextField setStringValue:shadertoyApiKey];
}


- (NSString *)validateFragmentShader:(NSString *)shaderString {

    shaderString = [[Shadertoy_ScreensaverView createShadertoyHeader] stringByAppendingString:shaderString];

    // Create a shader object
    GLuint shader = glCreateShader(GL_FRAGMENT_SHADER);

    // Convert NSString to C-string
    const char *shaderSource = [shaderString UTF8String];
    glShaderSource(shader, 1, &shaderSource, NULL);

    // Compile the shader
    glCompileShader(shader);

    // Check for compile errors
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *errorMessage = [NSString stringWithUTF8String:messages];
        NSLog(@"Shader Compilation Error: %@", errorMessage);
        return errorMessage;
    }

    return nil;
}


- (IBAction)doneButtonClicked:(id)sender
{
    // Save current text
    NSUserDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName];
    NSString *currentShaderID = [self.shadertoyShaderIDTextField stringValue];
    [defaults setObject:currentShaderID forKey:@"ShadertoyShaderID"];

    NSString *currentApiKey = [self.shadertoyAPIKeyTextField stringValue];
    [defaults setObject:currentApiKey forKey:@"ShadertoyApiKey"];

    NSString *requestUrl = [self createRequestString:currentShaderID apiKey:currentApiKey];

    [self.statusTextField setStringValue:@"Fetching shader"];

    [self fetchDataWithCompletion:^(NSData *data, NSError *error, NSHTTPURLResponse *response) {
        if (data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (response.statusCode != 200)
                {
                    [self.statusTextField setStringValue:@"Error from shadertoy"];
                }
                else
                {
                    [self.statusTextField setStringValue:@"Fetching shader was successful"];

                    NSString *shaderJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"shaderJson: %@ %d", shaderJson, response.statusCode);

                    NSError *jsonError;
                    NSData *jsonData = [shaderJson dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

                    if (!jsonObject) {
                        [self.statusTextField setStringValue:@"Invalid data received from Shadertoy"];
                    } else
                    {
                        NSString *errorMessage = jsonObject[@"Error"];
                        if (errorMessage) {
                            [self.statusTextField setStringValue:[NSString stringWithFormat:@"Invalid shader: %@", errorMessage]];
                        } else {
                            NSString *errorMessageCompile = [self validateFragmentShader:[Shadertoy_ScreensaverView getShaderStringFromJSON:jsonObject]];
                            if (errorMessageCompile != nil) {
                                [self.statusTextField setStringValue:[NSString stringWithFormat:@"Couldn't compile shader: %@", errorMessageCompile]];

                                NSAlert *alert = [[NSAlert alloc] init];
                                alert.messageText = @"Couldn't compile shader";

                                // Create a scrollable NSTextView
                                NSScrollView *scrollTextView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
                                [scrollTextView setHasVerticalScroller:YES];
                                [scrollTextView setBorderType:NSBezelBorder];

                                NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 290, 190)];
                                [textView setEditable:NO];
                                [textView setString:errorMessageCompile];
                                [scrollTextView setDocumentView:textView];

                                // Add the text view to the alert
                                [alert setAccessoryView:scrollTextView];

                                // Display the alert
                                [alert runModal];
                                
                            } else {
                                [defaults setObject:shaderJson forKey:@"ShaderJSON"];
                                [defaults synchronize];
                            }
                        }
                    }
                    
                    
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.statusTextField setStringValue:@"Error fetching shader"];
            });
        }
    } fullURL:requestUrl];

    [defaults synchronize];
}

- (IBAction)closeButtonClicked:(id)sender
{
    [[NSApplication sharedApplication] endSheet:self.window];
}

- (NSString *)createRequestString:(NSString*)url apiKey:(NSString*)apiKey
{
    NSString *baseUrl = @"https://www.shadertoy.com/api/v1/shaders/";
    NSString *urlWithShader = [baseUrl stringByAppendingString:url];
    NSString *urlWithApiKey = [[urlWithShader stringByAppendingString:@"?key="] stringByAppendingString:apiKey];

    return urlWithApiKey;
}

- (void)fetchDataWithCompletion:(void (^)(NSData *data, NSError *error, NSHTTPURLResponse *response))completion fullURL:(NSString*)fullURL {
    NSURL *url = [NSURL URLWithString:fullURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data,
                                                                NSURLResponse *response,
                                                                NSError *error) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        completion(data, error, r);
    }];

    [task resume];
}

@end
