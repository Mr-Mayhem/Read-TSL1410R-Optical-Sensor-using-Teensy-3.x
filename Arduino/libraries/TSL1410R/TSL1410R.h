/*
  TSL1410R.h - Library for reading TSL1410R linear photodiode array
  Created by Douglas Mayhew, November 8, 2016.
  Released into the public domain.
*/
#ifndef TSL1410R_h
#define TSL1410R_h

#include "Arduino.h"
#include "ADC.h" 	// Teensy ADC library

class TSL1410R
{
  public:
    TSL1410R(int CLKpin, int SIpin, int Apin1, int Apin2);
    uint16_t ExposureMicroseconds;
    void read(uint8_t * data, uint32_t len);
  private:
    int _CLKpin;
    int _SIpin;
    int _Apin1;
    int _Apin2;
    uint16_t _sample1;
    uint16_t _sample2;
    void initTSL1410R();
};


#endif