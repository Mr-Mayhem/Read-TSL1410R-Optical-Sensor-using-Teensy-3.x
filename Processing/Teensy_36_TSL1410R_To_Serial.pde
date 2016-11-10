// This sketch receives and displays a point plot of sensor data from incoming serial
// binary stream from a corresponding Arduino or Teensy TSL1410R sensor reader sketch.

// An Arduino or Teensy is wired to TSL1410R linear photodiode array chip, using the 
// sensor chip's parallel mode circuit suggestion, which reads two analog values 
// on each clock cycle applied to the sensor chip, (we don't use the sensor chip
// 'serial' mode which reads only one value per applied clock). 
// In the Teensy 3.x version of the Arduino sketch, we go one step further,
// and read both analog pixel values at the same instant, rather than sequentially.

// The Arduino sketch is programmed to send the sensor values over the usb serial 
// connection to a PC running this Processing sketch.

// Each integer sensor value is sent as two bytes over the serial 
// connection. The Arduino program sends one PREFIX byte of value 255 followed 
// by 512 data bytes, two data bytes per sensor value. 
// (1080 sensor pixels X 2 = 2560)

// ==============================================================================================
// Imports:

import processing.serial.*;

// ==============================================================================================
// Constants:

// TSL1410R linear photodiode array chip has 1080 total pixels
final int NPIXELS = 1280; 

// set this to the number of bits in each Teensy ADC value read from the sensor
final int NBITS_ADC = 12;

final int HIGHEST_ADC_VALUE = int(pow(2.0, float(NBITS_ADC))-1);

// number of screen pixels for each data point, used for drawing plot
final int WIDTH_PER_PT = 1;

// screen width
final int SCREEN_WIDTH = NPIXELS*WIDTH_PER_PT;

//  screen height = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR
final int SCREEN_HEIGHT_DIVISOR = 8;

//  screen height = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR
final int SCREEN_HEIGHT = HIGHEST_ADC_VALUE/SCREEN_HEIGHT_DIVISOR;

// twice the pixel count because we use 2 bytes to represent each sensor pixel
final int N_BYTES_PER_SENSOR_FRAME = NPIXELS * 2; //

// the data bytes + PREFIX byte
final int N_BYTES_PER_SENSOR_FRAME_PLUS1 = N_BYTES_PER_SENSOR_FRAME + 1; 

//used to sync the filling of byteArray to the incoming serial stream
final int PREFIX = 0xFF;  
//static final int PREFIX_B = 0x00;

// ==============================================================================================
// Arrays:

// array of raw serial data bytes
byte[] byteArray = new byte[N_BYTES_PER_SENSOR_FRAME]; 

// array of sensor values
int[] pixArray = new int[NPIXELS + 3]; 

// array of integer coefficients for calibrating data
int[] calCoefficients = new int[NPIXELS];  

// ==============================================================================================
// Global Variables:

// used for upscaling integers prior to mult or division so we don't need slower floating point
final int MathMultiplier = 256;   

final int SERIAL_NOT_ENOUGH_BYTES = 0;
final int SERIAL_SYNCING = 1;
final int SERIAL_READ_OK = 2;

// global sum of all sensor values (used for calibration)
int pixArraySum = 0; 

// global average of all sensor values for the current
// data frame 
// (used for calibration)
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
int prevSensorValue = 0;

float sensorPixelSpacing = 0.0635; //63.5 microns
float sensorPixelsPerMM = 15.74803149606299;
float sensorWidthAllPixels = 16.256; // millimeters

float widthsubpixellp = 2;
int captureCount = 0;

// ==============================================================================================
// Set the Serial Port object
Serial myPort;  

// ==============================================================================================

void setup() 
{
  // Set up main window
  surface.setSize(SCREEN_WIDTH, (SCREEN_HEIGHT) + 55); // screen width, height
  background(0); // Arduino green color
  strokeWeight(1); // thickness of lines and outlines
  stroke(255); // white lines and outlines
  noFill(); // outlines only for now
  textSize(15);
  frameRate(1000);
  zeroCoefficients();
 
  // Set up serial connection
  myPort = new Serial(this, "COM5", 12500000);
  myPort.clear();
}

void draw() {
  availableBytes = myPort.available();
  // If there are enough bytes
  if (availableBytes > N_BYTES_PER_SENSOR_FRAME_PLUS1) { 
    // Remove the next byte from the serial buffer, 
    // and compare it to PREFIX. 
    if (myPort.read() == PREFIX) {
      // we found PREFIX (unique byte value 255) and thus are synced, 
      //which means the sensor data immediately follows...
      bytesRead = myPort.readBytes(byteArray); // Read the sensor data bytes to byteArray[]
      chartRedraws++;
      if (chartRedraws >= 60) {
       chartRedraws = 0;
       availableBytesDraw = availableBytes;
      }
      background(0); // clear the canvas
      fill(255);
      text(chartRedraws, 10, 50);
      // show amount of bytes waiting in the serial buffer
      text(availableBytesDraw, 50, 50);
      
      //text(frameRate, 200, 22);

      // color the receive status indicator white to indicate a successful serial data read
      stroke(255);
      fill(255);
      rect(10, 15, 12, 12);
      
      //if (calRequestFlag) { // if a calibration was requested via mouseclick
      //  setCoefficients(); //set the calibration coefficients
      //}
      
      //pixArraySum = 0;
      //storeSensorValue(0);
      //prevSensorValue = pixArray[0];
      // Store and Display pixel values
      for(int i=0; i < NPIXELS; i++) {
        // Read a pair of bytes from the byte array, convert them into an integer, 
        // shift right 2 places, and 
        // copy result into pixArray[]
        pixArray[i] = (byteArray[i<<1]<< 8 | (byteArray[(i<<1) + 1] & 0xFF))>>2;
        //pixArraySum =+ pixArray[i];
        
        //// Apply calibration to pixArray[i] value if coefficients are set
        //if (isCalibrated) {
        //  pixArray[i] = (pixArray[i] * calCoefficients[i]) / MathMultiplier;
        //}
        
        // Plot a point on the canvas for this pixel
        stroke(255);
        //fill(255);
        point(i*WIDTH_PER_PT, SCREEN_HEIGHT - pixArray[i]/SCREEN_HEIGHT_DIVISOR);
        
        // prepare color to correspond to sensor pixel reading
        pixelColor = pixArray[i] /16;
        // Plot a row of pixels near the top of the screen ,
        // and color them with the 0 to 255 greyscale sensor value
        noStroke();
        fill(pixelColor, pixelColor, pixelColor);
        rect(i*WIDTH_PER_PT, 0, 4, 10);
      }
        //sensorAverageValue = pixArraySum / NPIXELS;
        
 
       // calculate and display shadow location with subpixel accuracy
       // calcAndDisplaySensorShadowPos();
    } else {
      // we are not synced
      // color the receive status indicator red to indicate not synced;
      stroke(255);
      fill(255, 255, 255);
      rect(10, 15, 12, 12);
    }
  } else {
    // color the receive status indicator to the background color to indicate not enough 
    // data is present in the receive serial data buffer this time around
    stroke(255);
    fill(0);
    rect(10, 15, 12, 12);
  }
  //captureCount++;
  //if (captureCount ==500) {
  //  captureCount = 0;
  //  saveFrame("Processing_Screen_Capture-######.png");
  //}
}

void setCoefficients() {
  calRequestFlag = false;
  isCalibrated = false;
  
  println("Calibrate Begin");

  for(int i=0; i < NPIXELS; i++) {
    if (pixArray[i] > 0) { // value is greater than zero
      // set the coeffieient
      calCoefficients[i] = (sensorAverageValue * MathMultiplier) / pixArray[i]; 
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

void calcAndDisplaySensorShadowPos()
{
  //double calibFactor = 31.38912669 / 2;

  int x0, x1, x2, x3;
  float minstep, maxstep;
  int minsteploc, maxsteploc;
  int ct;

  float a1, b1, c1, a2, b2, c2, m1, m2, mdiff; //sub pixel quadratic interpolation variables
  float widthsubpixel; 
  float filPrecisePos;
  float filPreciseMMPos;
  
  int filWidth = 0;
  int filPos = 0;
  int startPos = 0, endPos = NPIXELS;
  int subPixelX = 0;
  
  minstep = 0;
  maxstep = 0;
  minsteploc = 255; 
  maxsteploc = 255;
  //clear the sub-pixel buffers
  x0 = x1 = x2 = x3 = 0;
  a1 = b1 = c1 = a2 = b2 = c2 = m1 = m2 = 0;
  widthsubpixel = 0;
  ct = startPos-2;  //index to count samples  need to load buffer for 2 steps to subtract x2-x1

  for (int i=startPos; i<endPos; i++)
  {
    x3=x2;  
    x2=x1;
    x1=x0;
    x0=pixArray[i];
    ct = ct + 1;

    if (ct > startPos+1 && ct < endPos-2)
    {
      if (x1<x2)
      {
        if (minstep<x2-x1)
        {
          minstep=x2-x1;
          minsteploc=ct;
          c1=x1-x0;
          b1=x2-x1;
          a1=x3-x2;
        }
      } else if(x1>x2)
      {
        if (maxstep<x1-x2)
        {
          maxstep=x1-x2;
          maxsteploc=ct;
          c2=x1-x0;
          b2=x2-x1;
          a2=x3-x2;
        }
      }
    }
  }
  

  if (minstep>16 && maxstep>16)  //check for significant threshold
  {
    filWidth=maxsteploc-minsteploc;
  } else {
    filWidth=0;
  }
    
  if (filWidth>103)  //check for width overflow or out of range (15.7pixels per mm, 65535/635=103)
    {
      filWidth=0;
    }
   
    //sub-pixel edge detection using interpolation
    m1=((a1-c1) / (a1+c1-(b1*2)))/2;
    m2=((a2-c2) / (a2+c2-(b2*2)))/2;
    
    mdiff = m2-m1; 
    
    if (filWidth>10) {    //check for a measurement > 1mm  otherwise treat as noise
      widthsubpixel=filWidth+mdiff; 
      //widthsubpixellp = widthsubpixellp * 0.9 + widthsubpixel * 0.1;
      filPos = (filWidth/2) + minsteploc;
      filPrecisePos = minsteploc + (widthsubpixel/2);
    } else {
      widthsubpixel=0;
      filPos = 0;
      filPrecisePos = 0;
    }
     
     //widthsubpixellp = ((widthsubpixel - widthsubpixellp) * 0.1) + widthsubpixellp; 
     
      subPixelX = (filPos * WIDTH_PER_PT) + round(map(mdiff, -0.76, 0.76, -WIDTH_PER_PT/2, WIDTH_PER_PT/2));
      
      filPreciseMMPos = filPrecisePos * sensorPixelSpacing;
 
  // Mark minsteploc with green circle
  noFill();
  stroke(0, 255, 0);
  ellipse(minsteploc * WIDTH_PER_PT, SCREEN_HEIGHT-pixArray[minsteploc]/SCREEN_HEIGHT_DIVISOR, WIDTH_PER_PT, WIDTH_PER_PT);
 
  // Mark center of width ((filWidth/2) + minsteploc) with white circle
  
  stroke(255);
  ellipse(subPixelX, SCREEN_HEIGHT-pixArray[filPos]/SCREEN_HEIGHT_DIVISOR, WIDTH_PER_PT, WIDTH_PER_PT);

  // Mark maxsteploc with red circle
  stroke(255, 0, 0);
  ellipse(maxsteploc * WIDTH_PER_PT, SCREEN_HEIGHT-pixArray[maxsteploc]/SCREEN_HEIGHT_DIVISOR, WIDTH_PER_PT, WIDTH_PER_PT);      
      
    if (widthsubpixel > 0)
    {
      //float mmWidth = widthsubpixellp * sensorPixelSpacing;
      fill(255);
      //text("filWidth = " + filWidth, 10, SCREEN_HEIGHT-10);
      //text("widthsubpixel = " + String.format("%.3f", widthsubpixel), 200, SCREEN_HEIGHT-10);
      //text("mmWidth = " + String.format("%.3f", mmWidth), 400, SCREEN_HEIGHT-10);
      text("filPos = " + filPos, 10, SCREEN_HEIGHT-10);
      //text("subPixelX = " + subPixelX, 600, SCREEN_HEIGHT-10);
      text("filPrecisePos = " + String.format("%.3f", filPrecisePos), 200, SCREEN_HEIGHT-10);
      text("filPreciseMMPos = " + String.format("%.3f", filPreciseMMPos), 400, SCREEN_HEIGHT-10);
      
  }
}

void mousePressed() {
  println("mousePressed");
  if (isCalibrated){  // used to flip between modes using mouseclicks
    zeroCoefficients();
  } else {
    calRequestFlag = true;
  }
}