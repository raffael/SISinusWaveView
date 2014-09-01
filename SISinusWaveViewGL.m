//
//  SISinusWaveViewGL.m
//  VisVoiceKill
//
//  Created by Raffael Hannemann on 1/1/14.
//  Copyright (c) 2014 Raffael Hannemann. All rights reserved.
//

#import <OpenGL/gl.h>
#import "SISinusWaveViewGL.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>

@implementation SISinusWaveViewGL {
	NSTimer *_levelTimer;
	CGFloat _widthFactor;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _frequency = 1.5;
		_phase = 0;
		_amplitude = 1.0;
		_waveColor = [NSColor blackColor];
		_backgroundColor = [NSColor clearColor];
		_idleAmplitude = 0.1;
		_dampingFactor = 0.86;
		_waves = 5;
		_phaseShift = -0.15;
		_density = 5.0;
		_marginLeft = 0;
		_lineWidth = 2;
		_marginRight = 0;
		self.listen = YES;
		
		
		// Create a recorder instance, recording to /dev/null to trash the data immediately
		NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];
		NSError *error = nil;
		_recorder = [[AVAudioRecorder alloc] initWithURL:url settings:@{
																		AVSampleRateKey: @44100,
																		AVFormatIDKey: @(kAudioFormatAppleLossless),
																		AVNumberOfChannelsKey: @1,
																		AVEncoderAudioQualityKey: @(AVAudioQualityMax)
																		} error:&error];
		
		if (!_recorder || error) {
			NSLog(@"WARNING: %@ could not create a recorder instance (%@).", self, error.localizedDescription);
		} else {
			[_recorder prepareToRecord];
			_recorder.meteringEnabled = YES;
		}
    }
    return self;
}

- (void) prepareOpenGL {
	if ([self.window backingScaleFactor] > 1.0)
		[self setWantsBestResolutionOpenGLSurface:YES];
	_widthFactor = [self.window.screen backingScaleFactor];
}

#pragma mark - Customize the Audio Plot
-(void)awakeFromNib {
	[self setListen:YES];
}

- (void) setListen:(BOOL)listen {
	_listen = listen;
	if (_listen) {
		[_recorder record];
		if (_levelTimer)
			[_levelTimer invalidate];
		_levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.025 target:self selector:@selector(recorderDidRecord:) userInfo: nil repeats: YES];
		
	} else {
		[_recorder stop];
		if (_levelTimer)
			[_levelTimer invalidate];
		_amplitude = 0;
	}
	[self setNeedsDisplay:YES];
}

- (void) recorderDidRecord: (NSTimer *) timer {
	[_recorder updateMeters];
	
	int requiredTickes = 2; // Alter this to draw more or less often
	tick = (tick+1)%requiredTickes;
	
	// Get the recorder's current average power for the first channel, sanitize the value.
	float value = pow(10, (0.05 * [_recorder averagePowerForChannel:0])) > 0.05 ? 0.1 : 0;
	
	/// If we defined the current sound level as the amplitude of the wave, the wave would jitter very nervously.
	/// To avoid this, we use an inert amplitude that lifts slowly if the value is currently high, and damps itself
	/// if the value decreases.
	if (value > _dampingAmplitude) _dampingAmplitude += (fmin(value,1.0)-_dampingAmplitude)/4.0;
	else if (value<0.01) _dampingAmplitude *= _dampingFactor;
	
	_phase += _phaseShift;
	_amplitude = fmax( fmin(_dampingAmplitude*20, 1.0), _idleAmplitude);
	
	[self setNeedsDisplay:tick==0];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
	
	if ([self isHidden])
		return;
	
	if (!(self.window.occlusionState & NSWindowOcclusionStateVisible))
		return;
	
	[[self openGLContext] makeCurrentContext];
	
	float halfHeight = NSHeight(self.bounds)/2;
	float width = NSWidth(self.bounds)-_marginLeft-_marginRight;
	float mid = width /2.0;
	float stepLength = _density / width;
	
	CGFloat red = 0;
	CGFloat green = 0;
	CGFloat blue = 0;
	CGFloat alpha = 0;
	[self storeRGBValuesForColor:_backgroundColor inR:&red g:&green b:&blue a:&alpha];

	// Lock
	CGLLockContext([[self openGLContext] CGLContextObj]);
	glClearColor(red, green, blue, alpha);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Get view dimensions in pixels
    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
	
    GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
	backingPixelHeight = (GLsizei)(backingBounds.size.height);
	
    // Set viewport
    glViewport(0, 0, backingPixelWidth, backingPixelHeight);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	//gluOrtho2D(0., NSWidth(self.bounds), 0., NSHeight(self.bounds));
	glOrtho(0., NSWidth(self.bounds), 0., NSHeight(self.bounds), -1., 1.);
	
	glEnable (GL_LINE_SMOOTH);
	glEnable (GL_BLEND);
	
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glHint (GL_LINE_SMOOTH_HINT, GL_DONT_CARE);

	// We draw multiple sinus waves, with equal phases but altered amplitudes, multiplied by a parable function.
	for(int i=0;i<_waves+1;i++) {
		
		const float maxAmplitude = halfHeight-4; // 4 corresponds to twice the stroke width
		
		// Progress is a value between 1.0 and -0.5, determined by the current wave idx, which is used to alter the wave's amplitude.
		float progress = 1.0-(float)i/_waves;
		float normedAmplitude = (1.5*progress-0.5)*_amplitude;
		
		// Choose the color based on the progress (that is, based on the wave idx)
		CGFloat red = 0;
		CGFloat green = 0;
		CGFloat blue = 0;
		CGFloat alpha = 0;
		NSColor *nextColor = [self colorForLineAtLocation:0 percentalLength:0];
		[self storeRGBValuesForColor:nextColor inR:&red g:&green b:&blue a:&alpha];
		
		glColor4f(red,green,blue, alpha *(progress/3.0*2+1.0/3.0));
		
		CGFloat finalLineWidth = (i==0) ? _lineWidth:_lineWidth/2.0;
		finalLineWidth *= _widthFactor; // Double the line width according to the screen's backing scale factor
		
		glLineWidth(finalLineWidth);
		
		float lastX = _marginLeft;
		float lastY = halfHeight;
		
		glBegin(GL_LINES);
		[self drawLineFromSX:0 andSY:halfHeight toEX:lastX andEY:lastY];
		for(float x = 0; x<width+_density; x+=_density) {
			
			// We use a parable to scale the sinus wave, that has its peak in the middle of the view.
			float scaling = -pow(1/mid*(x-mid),2)+1;
			if (!_oscillating) {
				normedAmplitude = _idleAmplitude;
			}
			
			float y = scaling *maxAmplitude *normedAmplitude *sinf(2 *M_PI *(x / width) *_frequency +_phase) + halfHeight;
			
			CGFloat location = x/(width+_density);

			// Determine the color for this part of the wave, and alter its alpha value
			NSColor *stepColor = [self colorForLineAtLocation:location percentalLength:stepLength];
			CGFloat red = 0;
			CGFloat green = 0;
			CGFloat blue = 0;
			CGFloat alpha = 0;
			const CGFloat *components = CGColorGetComponents(stepColor.CGColor);
			red = components[0];
			green = components[1];
			blue = components[2];
			alpha = components[3];
			[self storeRGBValuesForColor:nextColor inR:&red g:&green b:&blue a:&alpha];
			glColor4f(red,green,blue, alpha *(progress/3.0*2+1.0/3.0));
			
			float lx = x + _marginLeft;
			[self drawLineFromSX:lastX andSY:lastY toEX:lx andEY:y];
			lastX = lx;
			lastY = y;
		}
		
		
		[self drawLineFromSX:NSWidth(self.bounds)-_marginRight andSY:halfHeight toEX:NSWidth(self.bounds) andEY:halfHeight];
		glEnd();
		
	}
	glFlush();
	
	// Flush and unlock
	CGLFlushDrawable([[self openGLContext] CGLContextObj]);
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
	
}

- (void) storeRGBValuesForColor: (NSColor *) source inR: (CGFloat *) r g: (CGFloat *) g b: (CGFloat *) b a: (CGFloat *) a {
	if (CGColorGetNumberOfComponents(source.CGColor) == 2) {
		const CGFloat *colorComponents = CGColorGetComponents(source.CGColor);
		*r = colorComponents[0];
		*g = colorComponents[0];
		*b = colorComponents[0];
		*a = colorComponents[1];
	}
	else if (CGColorGetNumberOfComponents(source.CGColor) == 4) {
		const CGFloat * colorComponents = CGColorGetComponents(source.CGColor);
		*r = colorComponents[0];
		*g = colorComponents[1];
		*b = colorComponents[2];
		*a = colorComponents[3];
	}
}

- (void) drawLineFromSX: (float) sx andSY: (float) sy toEX: (float) ex andEY: (float) ey {
	glVertex2d(sx, sy);
	glVertex2d(ex, ey);
}

- (NSColor *) colorForLineAtLocation: (CGFloat) location percentalLength: (CGFloat) length {
	return self.waveColor;
}

@end