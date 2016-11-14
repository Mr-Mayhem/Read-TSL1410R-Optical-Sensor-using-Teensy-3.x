# Read-TSL1410R-Optical-Sensor-using-Teensy-3.x
Includes Teensy 3.6 Arduino library, Example, Processing Demo.

Use a Teensy 3.x module to read the AMS TSL1410R optical sensor and plot pixel values in Processing.

Inspired by:
http://playground.arduino.cc/Main/TSL1402R

The TSL1402R linear photodiode array optical sensor (main page), also note the significant Technical Docs section:
http://ams.com/eng/Products/Light-Sensors/Linear-Array/TSL1410R

TSL1402R PDF Datasheet:
http://ams.com/eng/content/download/250184/975725/142518

Mouser Electronics Link:
http://www.mouser.com/ProductDetail/ams/TSL1410R/?qs=%2fha2pyFaduisKcdaT4ezeLBwrmpJGCjtYLJ530km9is%3d

Digikey Link:
https://www.digikey.com/product-search/en?keywords=TSL1410R

Arrow Electronics Link:
https://www.arrow.com/en/products/tsl1410r/ams-ag

Processing home page (Processing is used to plot the sensor data):
https://processing.org/

===============================================================================================================================
Latest improvements:
// This version includes different serial port code, using bufferuntil and serialevent, 
// which avoids a long start-up pause and latency.

// Added an interpolation feature, so setting NUM_INTERP_POINTS > 0 will draw green
// colored points in-between the original data points. They are stored in the data
// array alongside the original data. (The original data is spaced out in the array, 
// to allow room for the additional interpolated points) This setup is just for now, 
// soon, to gain efficiency, we will only interpolate the 'interesting data' where 
// the shadow is found, after some other soon-to-be-added DSP steps.
===============================================================================================================================

===============================================================================================================================
Future improvements:
===============================================================================================================================

Subpixel resolution edge detection.
Passing data on to ESP8266 Wifi to Processing app.
Remote control via serial or WiFi

===============================================================================================================================
Installation:
===============================================================================================================================

Wire the sensor to a Teensy on a breadboard, and consult the schematics in the TSL1402R datasheet, link above. 

Use the parallel circuit. 

The SI pin from Teensy 3.x are wired to pins 2, 3, 8, and 9 on the TSL1410R sensor which is SI1 and SI2 and HOLD1 and HOLD2, respectively.
The clock pin from Teensy 3.x goes to pins 4 and 10 on the TSL1410R senor. Forget one and see one half of the data missing in the plot.

Change each pin assignment in the code carefully to match your wiring and model of Teensy. 

Teensy 3.6 is what I set the pins to originally and thus needs no changes in the code, 
but the wires to the sensor chip still need to connect to the sensor correctly, of course.

In Arduino IDE, clicking File/Preferences brings up a dialog showing settings and your Arduino Sketchbook Location.

Copy the library folder TSL1410R and its files directly into your Arduino Sketchbook Location/libraries folder, 
and restart the Arduino IDE.

Then copy the Arduino and Processing sketches into the usual places, for example:

Your Arduino Sketchbook Location/Teensy_36_TSL1410R_To_Serial/Teensy_36_TSL1410R_To_Serial.ino 
--------------------------------------------------------------------------------------------------
Your Processing Sketchbook Location/Teensy_36_TSL1410R_To_Serial/Teensy_36_TSL1410R_To_Serial.pde
--------------------------------------------------------------------------------------------------

Open Arduino example file Teensy_36_TSL1410R_To_Serial.ino in the Arduino IDE, and upload it to Teensy 3.x. 

With the usb cable from the Teensy hooked up to your pc, Open the Processing sketch and run it. 

If it raises an error on the serial, make sure the com port is set right. It may be off by 1 or something like that. It should match the com port set in Arduino IDE under Tools >> Port when your Teensy board is selcted under Tools >> Board:.

You should see the frames counting up and the number of bytes in the serial buffer changing, and a plot of white dots that respond to changing light on the sensor. A bar along the top shows the individual pixel intensities as a greyscale color; black for dim light, white for bright light. A little square in the upper left corner is white while receiving data, red while syncing, and black while waiting for more data.

