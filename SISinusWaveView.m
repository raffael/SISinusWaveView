//
//  SISinusWaveView.m
//
//  Created by Raffael Hannemann on 12/28/13.
//  Copyright (c) 2013 Raffael Hannemann. All rights reserved.
//

#import "SISinusWaveView.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>

@implementation SISinusWaveView {
	NSTimer *_levelTimer;
}

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		// Set up default values
		_frequency = 1.5;
		_phase = 0;
		_amplitude = 1.0;
		_waveColor = [NSColor whiteColor];
		_backgroundColor = [NSColor clearColor];
		_idleAmplitude = 0.1;
		_dampingFactor = 0.8;
		_waves = 5;
		_phaseShift = -0.25;
		_density = 15.0;
		_marginLeft = 0;
		_marginRight = 0;
		_lineWidth = 2.0;
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
	
	int requiredTickes = 10; // Alter this to draw more or less often
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
	
	if (_clearOnDraw) {
		[_backgroundColor set];
		NSRectFill(self.bounds);
	}
	
	float halfHeight = NSHeight(self.bounds)/2;
	float width = NSWidth(self.bounds)-_marginLeft-_marginRight;
	float mid = width /2.0;
	float stepLength = _density / width;
	
	// We draw multiple sinus waves, with equal phases but altered amplitudes, multiplied by a parable function.
	for(int i=0;i<_waves+1;i++) {
		
		[[NSGraphicsContext currentContext] saveGraphicsState];
		NSGraphicsContext * nsGraphicsContext = [NSGraphicsContext currentContext];
		CGContextRef context = (CGContextRef) [nsGraphicsContext graphicsPort];
		
		// The first wave is drawn with a 2px stroke width, all others a with 1px stroke width.
		CGContextSetLineWidth(context, (i==0)? _lineWidth:_lineWidth*.5 );
		
		const float maxAmplitude = halfHeight-4; // 4 corresponds to twice the stroke width
		
		// Progress is a value between 1.0 and -0.5, determined by the current wave idx, which is used to alter the wave's amplitude.
		float progress = 1.0-(float)i/_waves;
		float normedAmplitude = (1.5*progress-0.5)*_amplitude;
		
		[[self colorForLineAtLocation:0 percentalLength:0] set];
		CGContextMoveToPoint(context, 0, halfHeight);
		CGContextAddLineToPoint(context, _marginLeft, halfHeight);
		CGContextStrokePath(context);
		
		CGFloat lastX = _marginLeft;
		CGFloat lastY = halfHeight;
		for(float x = 0; x<width+_density; x+=_density) {
			CGContextMoveToPoint(context, lastX, lastY);
			
			// We use a parable to scale the sinus wave, that has its peak in the middle of the view.
			float scaling = -pow(1/mid*(x-mid),2)+1;
			if (!_oscillating) {
				normedAmplitude = _idleAmplitude;
			}
			
			float y = scaling *maxAmplitude *normedAmplitude *sinf(2 *M_PI *(x / width) *_frequency +_phase) + halfHeight;
			
			CGContextAddLineToPoint(context, x+_marginLeft, y);
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
			
			NSColor *alteredColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha *(progress/3.0*2+1.0/3.0)];
			[alteredColor set];
			
			CGContextStrokePath(context);
			lastX = x+_marginLeft;
			lastY = y;
		}
		[[self colorForLineAtLocation:1.0 percentalLength:0] set];
		CGContextMoveToPoint(context, lastX, halfHeight);
		CGContextAddLineToPoint(context, NSWidth(self.bounds), halfHeight);
		CGContextStrokePath(context);
	}
}

- (NSColor *) colorForLineAtLocation: (CGFloat) location percentalLength: (CGFloat) length {
	return self.waveColor;
}

@end
