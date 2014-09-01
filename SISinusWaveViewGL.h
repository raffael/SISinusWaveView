//
//  SISinusWaveView.h
//
//  Created by Raffael Hannemann on 12/28/13.
//  Copyright (c) 2013 Raffael Hannemann. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** This NSView subclass can be used to visualize the microphone input similar to an effect used in Apple's Siri. */
@class AVAudioRecorder;

@interface SISinusWaveViewGL : NSOpenGLView {
	int tick; // Can be used to control the drawing FPS
}

#ifndef IBInspectable
#define IBInspectable /* */
#endif

/// The recorder object, whose sound level will be used.
@property (nonatomic,strong) AVAudioRecorder *recorder;

/// The amplitude that is used when the incoming microphone amplitude is near zero. Setting a value greater 0 provides a more vivid visualization.
@property (assign) float idleAmplitude;

/// The phase of the sinus wave. Default: 0.
@property (assign) IBInspectable float phase;

/// A flag that clears the view rect with the backgroundColor before re-drawing. Default: YES.
@property (assign) IBInspectable BOOL clearOnDraw;

/// The frequency of the sinus wave. The higher the value, the more sinus wave peaks you will have. Default: 1.5
@property (assign) IBInspectable float frequency;

/// The damping factor that is used to calm the wave down after a sound level peak. Default: 0.86
@property (assign) IBInspectable float dampingFactor;

/// The number of additional waves in the background. The more waves, to more CPU power is needed. Default: 4.
@property (assign) IBInspectable float waves;

/// The actual amplitude the view is visualizing. This amplitude is based on the microphone's amplitude
@property (assign) IBInspectable float amplitude;

/// The damped amplitude.
@property (assign) IBInspectable float dampingAmplitude;

/// The lines are joined stepwise, the more dense you draw, the more CPU power is used. Default: 5.
@property (assign) IBInspectable float density;

/// The phase shift that will be applied with each delivering of the microphone's value. A higher value will make the waves look more nervous. Default: -0.15.
@property (assign) float phaseShift;

/// The color to draw the waves with. Default: white.
@property (strong) IBInspectable NSColor *waveColor;

/// Set to NO, if you want to stop the view to oscillate. If an idleAmplitude is set, it will be used to keep the waves moving.
@property (assign,nonatomic) BOOL oscillating;

/// Set to NO, if you want the microphone to stop listening. Default: YES.
@property (assign,nonatomic) BOOL listen;

/// The width of the line to draw the waves with. Background lines will have half the width. Default: 2.
@property (assign) IBInspectable float lineWidth;

/// The color to draw the background with. Default: clearColor.
@property (strong) IBInspectable NSColor *backgroundColor;

/// The left and right margin between view bounds and the wave oscillation beginning. Default: 0.
@property (assign) IBInspectable float marginLeft;
@property (assign) IBInspectable float marginRight;

/// Override the following method to provide a custom color per location.
- (NSColor *) colorForLineAtLocation: (CGFloat) location percentalLength: (CGFloat) length;

@end
