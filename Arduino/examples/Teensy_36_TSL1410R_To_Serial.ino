/*
   - Demo Sketch for reading TSL1410R linear photodiode array
  Uses TSL1410R.h class library for Teensy 3.x by Douglas Mayhew

  Use with PC running matching Processing app to xy plot the pixel values
  
  Created by Douglas Mayhew, November, 8 2016.
  Released into the public domain.
  
  Paired originally with a basic data visualizer written in Processing for viewing the output:
  https://github.com/Mr-Mayhem/Read-TSL1410R-Optical-Sensor-using-Teensy-3.x/tree/master/Processing
  
  Do not neglect to try my latest data visualizer written in Processing 
  (with all subpixel resolution and many more cool features):
  (If you try it, remember to set sigGenOutput to 3 and SENSOR_PIXELS to 1280)
  https://github.com/Mr-Mayhem/Linear_Array_Sensor_Subpixel_Visualizer
*/
#include <TSL1410R.h>
#include <ADC.h> // https://github.com/pedvide/ADC
//========================================================================================
// Pins for the TSL1410R sensor.
#define CLKpin  24 // <-- Teensy 3.6 pin delivering the clock pulses to pins 4 and 10 (CLK) of the TSL1410R
#define SIpin   25 // <-- Teensy 3.6 pin delivering the SI (serial-input) pulse to pins 2, 3, 8, and 9 of the TSL1410R
#define Apin1   14 // <-- Teensy 3.6 pin connected to pin 6 (analog output 1) of the TSL1410R
#define Apin2   39 // <-- Teensy 3.6 pin connected to pin 12 (analog output 2) of the TSL1410R (parallel mode only)
// Discussion at: https://forum.pjrc.com/threads/39376-New-library-and-example-Read-TSL1410R-Optical-Sensor-using-Teensy-3-x
//========================================================================================
ADC *adc = new ADC(); // adc object;
ADC::Sync_result ADCresult; // makes Teensy ADC library read 2 pins at the same time using 2 seperate ADCs
//========================================================================================
#define PREFIX 0xff
uint8_t sensorByteArray[2560];

void initADC()
{
    // This code is used to init the Teensy ADC library. We use this to gain more control, faster read, 
    // and ability to read two pixel values at the same moment, cutting read time in half.
    ///// ADC0 ////
    // reference can be ADC_REF_3V3, ADC_REF_1V2 (not for Teensy LC) or ADC_REF_EXT.
    //adc->setReference(ADC_REF_1V2, ADC_0); // change all 3.3 to 1.2 if you change the reference to 1V2

    adc->setAveraging(1); // set number of averages
    adc->setResolution(12); // set bits of resolution

    // it can be ADC_VERY_LOW_SPEED, ADC_LOW_SPEED, ADC_MED_SPEED, ADC_HIGH_SPEED_16BITS, ADC_HIGH_SPEED or ADC_VERY_HIGH_SPEED
    // see the documentation for more information
    adc->setConversionSpeed(ADC_HIGH_SPEED); // change the conversion speed
    // it can be ADC_VERY_LOW_SPEED, ADC_LOW_SPEED, ADC_MED_SPEED, ADC_HIGH_SPEED or ADC_VERY_HIGH_SPEED
    adc->setSamplingSpeed(ADC_HIGH_SPEED); // change the sampling speed

    //adc->enableInterrupts(ADC_0);

    // always call the compare functions after changing the resolution!
    //adc->enableCompare(1.0/3.3*adc->getMaxValue(ADC_0), 0, ADC_0); // measurement will be ready if value < 1.0V
    //adc->enableCompareRange(1.0*adc->getMaxValue(ADC_0)/3.3, 2.0*adc->getMaxValue(ADC_0)/3.3, 0, 1, ADC_0); // ready if value lies out of [1.0,2.0] V

    ////// ADC1 /////
    #if ADC_NUM_ADCS>1
    adc->setAveraging(1, ADC_1); // set number of averages
    adc->setResolution(12, ADC_1); // set bits of resolution
    adc->setConversionSpeed(ADC_HIGH_SPEED, ADC_1); // change the conversion speed
    adc->setSamplingSpeed(ADC_HIGH_SPEED, ADC_1); // change the sampling speed

    // always call the compare functions after changing the resolution!
    //adc->enableCompare(1.0/3.3*adc->getMaxValue(ADC_1), 0, ADC_1); // measurement will be ready if value < 1.0V
    //adc->enableCompareRange(1.0*adc->getMaxValue(ADC_1)/3.3, 2.0*adc->getMaxValue(ADC_1)/3.3, 0, 1, ADC_1); // ready if value lies out of [1.0,2.0] V
    #endif
}
// arguments are CLKpin, SIpin, Apin1, Apin2
TSL1410R Sensor(CLKpin, SIpin, Apin1, Apin2);  // sensor object

void setup()
{
  // always is 12.5 megabits per second (12500000) on Teensy 3.6, despite this setting
  Serial.begin(12500000); 
  initADC();

  // Set the length of time that light is collected before starting the read-out: 
  // A higher setting increases data height and sensitivity, but takes more time and slows down the framerate.
  // A lower setting decreases data height and sensitivity, but takes less time and speeds up the framerate.
  // I use 750 to 1000 for most casual experiments with a bright LED, but the same light source in close 
  // proximity will need less, so experiment to find the sweet spot.
  Sensor.ExposureMicroseconds = 750;
}

void loop() 
{
  // delay(10); // I slow Teensy 3.6 down so Processing sketch can keep up. Adjust or comment out as needed.
  Sensor.read(sensorByteArray, 2560);
  Serial.write(PREFIX); // PREFIX
  Serial.write(sensorByteArray, 2560);
}
