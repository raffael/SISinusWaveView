//
//  SISinusWaveView.m
//
//  Created by Raffael Hannemann on 12/28/13.
//  Updated for iOS by Benjamin Martin on 6/2/14.
//  Copyright (c) 2013 Raffael Hannemann. All rights reserved.
//

#import "SISinusWaveView.h"

@implementation SISinusWaveView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		_microphone = [EZMicrophone microphoneWithDelegate:self];
        _frequency = 1.5;
		_phase = 0;
		_amplitude = 1.0;
		_whiteValue = 1.0;
		_idleAmplitude = 0.1;
		_dampingFactor = 0.86;
		_waves = 5;
		_phaseShift = -0.15;
		_density = 5.0;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
		_microphone = [EZMicrophone microphoneWithDelegate:self];
        _frequency = 1.5;
		_phase = 0;
		_amplitude = 1.0;
		_whiteValue = 1.0;
		_idleAmplitude = 0.0;
		_dampingFactor = 0.86;
		_waves = 5;
		_phaseShift = -0.15;
		_density = 5.0;
    }
    return self;
}

#pragma mark - Customize the Audio Plot
-(void)awakeFromNib {
	[self setOscillating:YES];
}

#pragma mark - EZMicrophoneDelegate
#warning Thread Safety

-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
	
	dispatch_async(dispatch_get_main_queue(),^{
		
		int requiredTickes = 1; // Alter this to draw more or less often
		tick = (tick+1)%requiredTickes;
		
		// Let's use the buffer's first float value to determine the current sound level.
		float value = fabsf(*buffer[0]);
		
		/// If we defined the current sound level as the amplitude of the wave, the wave would jitter very nervously.
		/// To avoid this, we use an inert amplitude that lifts slowly if the value is currently high, and damps itself
		/// if the value decreases.
		if (value > _dampingAmplitude) _dampingAmplitude += (fmin(value,1.0)-_dampingAmplitude)/4.0;
		else if (value<0.01) _dampingAmplitude *= _dampingFactor;
		
		_phase += _phaseShift;
		_amplitude = fmax( fmin(_dampingAmplitude*20, 1.0), _idleAmplitude);
        
        if (tick == 0) {
            [self setNeedsDisplay];
        }
	});
}

- (void) setOscillating:(BOOL)oscillating {
	_oscillating = oscillating;
	if (oscillating)
		[_microphone startFetchingAudio];
	else {
		[_microphone stopFetchingAudio];
		_amplitude = 0;
	}
	[self setNeedsDisplay];
}
#pragma mark - Drawing

- (void)drawRect:(CGRect)dirtyRect {
	
	// We draw multiple sinus waves, with equal phases but altered amplitudes, multiplied by a parable function.
	for(int i=0;i<_waves+1;i++) {
		
        CGContextRef context = UIGraphicsGetCurrentContext();
		
		// The first wave is drawn with a 2px stroke width, all others a with 1px stroke width.
		CGContextSetLineWidth(context, (i==0)? 2:1 );
		
		float halfHeight = (self.bounds.size.height)/2;
		float width = NSWidth(self.bounds.size.width);
		float mid = width /2.0;
		
		const float maxAmplitude = halfHeight-4; // 4 corresponds to twice the stroke width
		
		// Progress is a value between 1.0 and -0.5, determined by the current wave idx, which is used to alter the wave's amplitude.
		float progress = 1.0-(float)i/_waves;
		float normedAmplitude = (1.5*progress-0.5)*_amplitude;
		
		// Choose the color based on the progress (that is, based on the wave idx)
		[[UIColor colorWithRed:(255/255.f) green:(255/255.f) blue:(255/255.f) alpha:progress/3.0*2+1.0/3.0] set];
		
		for(float x = 0; x<width+_density; x+=_density) {
			
			// We use a parable to scale the sinus wave, that has its peak in the middle of the view.
			float scaling = -pow(1/mid*(x-mid),2)+1;
            
			float y = scaling *maxAmplitude *normedAmplitude *sinf(2 *M_PI *(x / width) *_frequency +_phase) + halfHeight;
			
			if (x==0) CGContextMoveToPoint(context, x, y);
			else CGContextAddLineToPoint(context, x, y);
		}
		
		CGContextStrokePath(context);
	}
}

@end
