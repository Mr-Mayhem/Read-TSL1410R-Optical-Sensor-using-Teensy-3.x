/*
   - Demo Sketch for reading TSL1410R linear photodiode array
  Uses TSL1410R.h class library for Teensy 3.x by Douglas Mayhew

  Use with PC running matching Processing app to xy plot the pixel values
  
  Created by Douglas Mayhew, November, 8 2016.
  Released into the public domain.
*/
#include <TSL1410R.h>
#include <ADC.h> // https://github.com/pedvide/ADC
//========================================================================================
// Pins for the TSL1410R sensor.
#define CLKpin  24 // <-- Teensy 3.6 pin delivering the clock pulses to pin 4(CLK) of the TSL1410R
#define SIpin   25 // <-- Teensy 3.6 pin delivering the SI (serial-input) pulse to pin 2 of the TSL1410R
#define Apin1   14 // <-- Teensy 3.6 pin connected to pin 6 (analog output 1) of the TSL1410R
#define Apin2   39 // <-- Teensy 3.6 pin connected to pin 12 (analog output 2) of the TSL1410R (parallel mode only)
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
TSL1410R Sensor(CLKpin, SIpin, Apin1, Apin2);  //sensor object

void setup() 
{
  Serial.begin(115200);
  initADC();
  Sensor.ExposureMicroseconds = 500;
}

void loop() 
{
  delay(15); // I slow Teensy 3.6 down so Processing sketch can keep up. Adjust or comment out as needed.
  Sensor.read(sensorByteArray, 2560);
  Serial.write(PREFIX); // PREFIX
  Serial.write(sensorByteArray, 2560);
}
