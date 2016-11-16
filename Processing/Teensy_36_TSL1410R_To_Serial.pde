/*
Teensy_36_TSL1410R_To_Serial.pde, 
This sketch receives and displays a point plot of sensor data from incoming serial
// binary stream from a corresponding Arduino or Teensy TSL1410R sensor reader sketch.

Created by Douglas Mayhew, November 1, 2016.

Released into the public domain.

See: https://github.com/Mr-Mayhem/Teensy_36_TSL1410R_To_Serial/
*/

// This sketch receives and displays a point plot of sensor data from incoming serial
// binary stream from a corresponding Arduino or Teensy sensor reader sketch.

// This version includes different serial port code, using buffer until and serial event, 
// which avoids a long start-up pause and latency.

// Added an interpolation feature, so setting NUM_INTERP_POINTS > 0 will draw green
// colored points in-between the original data points in areas in deep shadow. 
// They are stored in the data array alongside the original data. 
// (The original data is spaced out in the array,  to allow room for the additional 
// interpolated points)

// An Arduino or Teensy is wired to the sensor, using the sensor chip's parallel-mode 
// circuit suggestion, which reads two analog values on each clock cycle applied to the 
// sensor chip, (we don't use the sensor chip 'serial' mode which reads only one value 
// per applied clock). 

// In the Teensy 3.x version of the Arduino sketch, we go one step further than usual,
// and read both analog pixel values at the same instant using seperate on-chip ADCs, 
// rather than sequentially.

// The Arduino sketch is programmed to send the sensor values over the USB serial 
// connection to a PC running this Processing sketch.

// Each integer sensor value is sent as two bytes over the serial 
// connection. The Arduino program sends one PREFIX byte of value 255 followed 
// by the data bytes, two per sensor value. 

// ==============================================================================================
// imports:

import processing.serial.*;
// ==============================================================================================
// colors
color COLOR_ORIGINAL_DATA = color(255);                   // white
color COLOR_INTERPERPOLATED_DATA   = color(0, 255, 0);    // red
color COLOR_COVOLUTION_IMPULSE_DATA = color(255, 255, 0); //yellow
color COLOR_COVOLUTION_OUTPUT_DATA = color(255,165,0);    // orange
color COLOR_PARABOLA_FIT_DATA = color(0,255,255);         // cyan
// ==============================================================================================
// Constants:

// TSL1402R linear photodiode array chip has 256 total pixels
final int SENSOR_PIXELS = 1280;

// set this to the number of bits in each Teensy ADC value read from the sensor
final int NBITS_ADC = 12;

final int HIGHEST_ADC_VALUE = int(pow(2.0, float(NBITS_ADC))-1);

// number of screen pixels for each data point, used for drawing plot 
final int SCREEN_X_MULTIPLIER = 2;

// screen width
final int SCREEN_WIDTH = SENSOR_PIXELS*SCREEN_X_MULTIPLIER;

//  screen height = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR
final int SCREEN_HEIGHT_DIVISOR = 8;

//  screen height = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR
final int SCREEN_HEIGHT = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR;

// number of extra inserted data points for each original data point
final int NUM_INTERP_POINTS = 3; 

// spacing of original data in the array
final int RAW_DATA_SPACING = NUM_INTERP_POINTS + 1;  

//number of discrete values in the output array
final int INTERP_OUT_LENGTH = (SENSOR_PIXELS * RAW_DATA_SPACING) - NUM_INTERP_POINTS; 

// twice the pixel count because we use 2 bytes to represent each sensor pixel
final int N_BYTES_PER_SENSOR_FRAME = SENSOR_PIXELS * 2; //

// the data bytes + PREFIX byte
final int N_BYTES_PER_SENSOR_FRAME_PLUS1 = N_BYTES_PER_SENSOR_FRAME + 1; 

//used to sync the filling of byteArray to the incoming serial stream
final int PREFIX = 0xFF;  
//static final int PREFIX_B = 0x00;

// used for upscaling integers prior to mult or division so we don't need slower 
// floating point, used only in calibration routines and currently commented out
final int MathMultiplier = 256;   

// use even impulseDataLength to 
//produce an even integer phase offset
final int IMPULSE_KERNEL_DATA_LENGTH = 19; 

final int CONVOLUTION_OUTPUT_DATA_LENGTH = SENSOR_PIXELS + IMPULSE_KERNEL_DATA_LENGTH;
//  a decimal fraction between 0 and 1, representing smaller increment of x position 
// relative to original data points. 

// sensor pixel values below this level are interpolated if NUM_INTERP_POINTS > 0
final int DIM_THESHOLD = 3000; 

// This is the decimal fraction of each step during interpolation, 
// and is used as an argument into the interpolation function
final float muIncrement = 1/float(RAW_DATA_SPACING);
// ==============================================================================================
// Arrays:
// array of raw serial data bytes
byte[] byteArray = new byte[N_BYTES_PER_SENSOR_FRAME+1]; 

// array for sensor data and interpolated data all together
int[] data_Array = new int[INTERP_OUT_LENGTH];

//int[] convolutionArray = new int[CONVOLUTION_OUTPUT_DATA_LENGTH];

// array of integer coefficients for calibrating data
int[] calCoefficients = new int[INTERP_OUT_LENGTH]; 

// ==============================================================================================
// Global Variables:

// global sum of all sensor values (used for calibration)
int sensorPixelSum = 0; 

// global average of all sensor values for the current data frame  (used for calibration)
int sensorAverageValue = 0; 

// used to flip between modes using mouseclicks
boolean isCalibrated = false;  

// triggers setting of coefficients; toggle via 
// mouseclick
boolean calRequestFlag = false; 

// number of bytes actually read out from the serial buffer
int bytesRead = 0;

// used to count frames
int chartRedraws = 0;

// used to store the number of bytes present in the serial buffer
int availableBytes = 0;

// used to show the number of bytes present in the serial buffer
int availableBytesDraw = 0;

int lowestBrightness = 2000;
int dimmestPixel = 0;
int pixelColor = 0;
boolean thresholdTriggered = false;

float sensorPixelSpacing = 0.0635; //63.5 microns
float sensorPixelsPerMM = 15.74803149606299;
float sensorWidthAllPixels = 16.256; // millimeters

float widthsubpixellp = 2;
int captureCount = 0;

int outerPtr = 0;          // outer loop pointer
int innerPtr = 0;          // inner loop pointer
int interpPtr = 0;         // interpolation pointer
int scaledXOffset = 0;     // interpolation X offset scaled to match the screen X (width) scaling
int Raw_Data_Ptr_A = 0;    //indexes for original data, feeds interpolation function inputs
int Raw_Data_Ptr_B = 0;
int Raw_Data_Ptr_C = 0;    // use for linear or cosine, also edit 'outerPtr-2' in inner loop to 'outerPtr'
int Raw_Data_Ptr_D = 0;    // use for linear or cosine, also edit 'outerPtr-2' in inner loop to 'outerPtr'

// decimal fraction between 0 and 1, 
//proportional to interpolated x axis between original points
float muValue = 0; 

// ==============================================================================================
// Set Objects
Serial myPort;  
// ==============================================================================================

void setup() 
{
  // Set up main window

  surface.setSize(SCREEN_WIDTH, (SCREEN_HEIGHT) + 55); // screen width, height
  zeroCoefficients();
  background(0); // Arduino green color
  strokeWeight(1); // thickness of lines and outlines
  stroke(255); // white lines and outlines
  noFill(); // outlines only for now
  textSize(15);
  frameRate(500);
  noLoop();
  
  // Set up serial connection
  myPort = new Serial(this, "COM5", 12500000);
  // the serial port will buffer until prefix (unique byte that equals 255) and then fire serialEvent()
  myPort.bufferUntil(PREFIX);
}

void serialEvent(Serial p) { 
  // copy one complete sensor frame of data, plus the prefix byte, into byteArray[]
  bytesRead = p.readBytes(byteArray);
  redraw();
} 

void draw() {
  chartRedraws++;
  thresholdTriggered = false;
  if (chartRedraws >= 60) {
   chartRedraws = 0;
   availableBytesDraw = myPort.available();
  }
  background(0); // clear the canvas
  fill(255);
  text(chartRedraws, 10, 50);
  // show amount of bytes waiting in the serial buffer
  text(availableBytesDraw, 50, 50);
  
  //if (calRequestFlag) { // if a calibration was requested via mouseclick
  //  setCoefficients(); //set the calibration coefficients
  //}
  
  // Store and Display pixel values
  for(outerPtr=0; outerPtr < SENSOR_PIXELS; outerPtr++) {
    Raw_Data_Ptr_A = (outerPtr - 3) * RAW_DATA_SPACING;
    Raw_Data_Ptr_B = (outerPtr - 2) * RAW_DATA_SPACING;   
    Raw_Data_Ptr_C = (outerPtr - 1) * RAW_DATA_SPACING;
    Raw_Data_Ptr_D = outerPtr * RAW_DATA_SPACING;

    // Read a pair of bytes from the byte array, convert them into an integer, 
    // shift right 2 places, and copy result into data_Array[]
    data_Array[Raw_Data_Ptr_D] = (byteArray[outerPtr<<1]<< 8 | (byteArray[(outerPtr<<1) + 1] & 0xFF))>>2;
    
    //// Apply calibration to data_Array[i] value if coefficients are set
    //if (isCalibrated) {
    //  data_Array[i] = (data_Array[i] * calCoefficients[i]) / MathMultiplier;
    //}
    
    // Plot a point on the canvas for this pixel
    stroke(COLOR_ORIGINAL_DATA);
    point(outerPtr*SCREEN_X_MULTIPLIER, SCREEN_HEIGHT - (data_Array[Raw_Data_Ptr_D]/SCREEN_HEIGHT_DIVISOR));
    
    // prepare color to correspond to sensor pixel reading
    pixelColor = int(map(data_Array[Raw_Data_Ptr_D], 0, HIGHEST_ADC_VALUE, 0, 255));
    // Plot a row of pixels near the top of the screen ,
    // and color them with the 0 to 255 greyscale sensor value
    noStroke();
    fill(pixelColor, pixelColor, pixelColor);
    rect(outerPtr*SCREEN_X_MULTIPLIER-1, 0, 4, 10);
    
    // Interpolation loop
    //println("outerPtr: " + outerPtr + " Raw_Data_Ptr_A: " + Raw_Data_Ptr_A + " Raw_Data_Ptr_B: " + Raw_Data_Ptr_B + " Raw_Data_Ptr_C: " + Raw_Data_Ptr_C + " Raw_Data_Ptr_D: " + Raw_Data_Ptr_D);
    if (Raw_Data_Ptr_A > -1) {
      if ((data_Array[Raw_Data_Ptr_A] < DIM_THESHOLD) && (data_Array[Raw_Data_Ptr_B] < DIM_THESHOLD) && (data_Array[Raw_Data_Ptr_C] < DIM_THESHOLD) && (data_Array[Raw_Data_Ptr_D] < DIM_THESHOLD)) { // Thresholding; ignore other data
        for (innerPtr = 1; innerPtr < RAW_DATA_SPACING; innerPtr++) {
          interpPtr = Raw_Data_Ptr_A + innerPtr;
          muValue = muIncrement * innerPtr; // increment mu
          
          //println("outerPtr: " + outerPtr + " innerPtr: " + innerPtr + " interpPtr: " + interpPtr + " muValue: " + muValue);
          
          data_Array[interpPtr] = int(Catmull_Rom_Interpolate(data_Array[Raw_Data_Ptr_A], data_Array[Raw_Data_Ptr_B], data_Array[Raw_Data_Ptr_C], data_Array[Raw_Data_Ptr_D], muValue));
   
          // scale the X offset for the screen
          scaledXOffset = int(map(innerPtr, 0, RAW_DATA_SPACING, 0, SCREEN_X_MULTIPLIER)); 
          
          // plot an interpolated point using the scaled x offset
          stroke(COLOR_INTERPERPOLATED_DATA);
          point(((outerPtr-2)*SCREEN_X_MULTIPLIER)+scaledXOffset, SCREEN_HEIGHT - (data_Array[interpPtr]/SCREEN_HEIGHT_DIVISOR));
         }
      }
    }
  }
}

void setCoefficients() {
  calRequestFlag = false;
  isCalibrated = false;
  
  println("Calibrate Begin");

  for(int i=0; i < SENSOR_PIXELS; i++) {
    if (data_Array[i] > 0) { // value is greater than zero
      // set the coeffieient
      calCoefficients[i] = round((sensorAverageValue * MathMultiplier) / data_Array[i]); 
      println(i + " " + calCoefficients[i]);
    } else { // value is less than zero
    //abort the calibration and reset all the coefficients
      zeroCoefficients();
      break;
    }
  }
  isCalibrated = true;
}

void zeroCoefficients() {
  isCalibrated = false;
  
  for(int i=0; i < calCoefficients.length; i++) {
    
    // set the default coeffieient which results in no calibration net effect for 
    // this sensor pixel
    
    calCoefficients[i] = MathMultiplier;
    //println(i + " " + calCoefficients[i]);
  }
}

float LinearInterpolate(float y1, float y2, float mu)
{
   return(y1*(1-mu)+y2*mu);
}

public float CosineInterpolate(float y1, float y2, float mu) {
   float mu2;

   mu2 = (1-cos(mu*PI))/2;
   return(y1*(1-mu2)+y2*mu2);
}

float CubicInterpolate(float y0,float y1, float y2,float y3, float mu)
{
   float a0,a1,a2,a3,mu2;

   mu2 = mu*mu;
   a0 = y3 - y2 - y0 + y1;
   a1 = y0 - y1 - a0;
   a2 = y2 - y0;
   a3 = y1;

   return(a0*mu*mu2+a1*mu2+a2*mu+a3);
}

float Catmull_Rom_Interpolate(float y0,float y1, float y2,float y3, float mu)
{
  
  // Originally from Paul Breeuwsma http://www.paulinternet.nl/?page=bicubic
  // "We could simply use derivative 0 at every point, but we obtain 
  // smoother curves when we use the slope of a line between the 
  // previous and the next point as the derivative at a point. In that 
  // case the resulting polynomial is called a Catmull-Rom spline."
  // Copied from version at http://paulbourke.net/miscellaneous/interpolation/

   float a0,a1,a2,a3,mu2;
   mu2 = mu*mu;
   a0 = -0.5*y0 + 1.5*y1 - 1.5*y2 + 0.5*y3;
   a1 = y0 - 2.5*y1 + 2*y2 - 0.5*y3;
   a2 = -0.5*y0 + 0.5*y2;
   a3 = y1;

   return(a0*mu*mu2+a1*mu2+a2*mu+a3);
}

//void mousePressed() {
//  println("mousePressed");
//  if (isCalibrated){  // used to flip between modes using mouseclicks
//    zeroCoefficients();
//  } else {
//    calRequestFlag = true;
//  }
//}