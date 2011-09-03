#include "cpu_light.h"

/**
 * From http://www.arduino.cc/playground/Code/PwmFrequency
 * Divides a given PWM pin frequency by a divisor.
 * 
 * The resulting frequency is equal to the base frequency divided by
 * the given divisor:
 *   - Base frequencies:
 *      o The base frequency for pins 3, 9, 10, and 11 is 31250 Hz.
 *      o The base frequency for pins 5 and 6 is 62500 Hz.
 *   - Divisors:
 *      o The divisors available on pins 5, 6, 9 and 10 are: 1, 8, 64,
 *        256, and 1024.
 *      o The divisors available on pins 3 and 11 are: 1, 8, 32, 64,
 *        128, 256, and 1024.
 * 
 * PWM frequencies are tied together in pairs of pins. If one in a
 * pair is changed, the other is also changed to match:
 *   - Pins 5 and 6 are paired.
 *   - Pins 9 and 10 are paired.
 *   - Pins 3 and 11 are paired.
 * 
 * Note that this function will have side effects on anything else
 * that uses timers:
 *   - Changes on pins 3, 5, 6, or 11 may cause the delay() and
 *     millis() functions to stop working. Other timing-related
 *     functions may also be affected.
 *   - Changes on pins 9 or 10 will cause the Servo library to function
 *     incorrectly.
 * 
 * Thanks to macegr of the Arduino forums for his documentation of the
 * PWM frequency divisors. His post can be viewed at:
 *   http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1235060559/0#4
 */
void setPwmFrequency(int pin, int divisor) {
  byte mode;
  if(pin == 5 || pin == 6 || pin == 9 || pin == 10) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 64: mode = 0x03; break;
      case 256: mode = 0x04; break;
      case 1024: mode = 0x05; break;
      default: return;
    }
    if(pin == 5 || pin == 6) {
      TCCR0B = TCCR0B & 0b11111000 | mode;
    } else {
      TCCR1B = TCCR1B & 0b11111000 | mode;
    }
  } else if(pin == 3 || pin == 11) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 32: mode = 0x03; break;
      case 64: mode = 0x04; break;
      case 128: mode = 0x05; break;
      case 256: mode = 0x06; break;
      case 1024: mode = 0x7; break;
      default: return;
    }
    TCCR2B = TCCR2B & 0b11111000 | mode;
  }
}

// Use PWMs that are on a different timer than millis() and delay()
#define RED 3
#define GREEN 9
#define BLUE 10

#define LED_COUNT 3

#define MESSAGE_START 0xFF

#define COLOR_MESSAGE_END 0xF0
#define COLOR_MESSAGE_LENGTH 3
#define COLOR_INDEX_RED 0
#define COLOR_INDEX_GREEN 1
#define COLOR_INDEX_BLUE 2

#define INTERVAL_MESSAGE_END 0xF1
#define INTERVAL_MESSAGE_LENGTH 2
#define INTERVAL_MSB_INDEX 0
#define INTERVAL_LSB_INDEX 1

#define BUFFER_SIZE 10

byte bytesRead = 0;
byte buffer[BUFFER_SIZE];

byte displayIndex = 0;
/**
* These are the pins that toggle an LED to be on.
* I'm using NPN transistors connected the common cathode to ground.
* When an output is high it, the transistor is allowing current to flow through 
* the LED to ground. When it is low no current is flowing.
**/
byte displayAddresses[] = {11, 12, 13};

Color currentColor = {0, 255, 0};
Color nextColor = {0, 255, 0};

unsigned long fadeStartTime = millis();
short fadeTime = 1000;

void setup () {
  Serial.begin(9600);
  
  // Set a high PWM frequency so it works with our high multiplex rate
  setPwmFrequency(RED, 1);
  setPwmFrequency(GREEN, 1);
  pinMode(RED, OUTPUT);
  pinMode(GREEN, OUTPUT);
  pinMode(BLUE, OUTPUT);
  
  // Set pin modes for display toggles.
  for (short i = 0; i < LED_COUNT; i++) {
   pinMode(displayAddresses[i], OUTPUT); 
  }
}

/**
* Writes the color at brightness level for address
**/
void writeColor(Color color, byte brightness, byte address) {
  // Keep track of the previous address or LED that was on so we may turn it off
  static byte previousAddress;
  
  // Switch from previousAddress to address
  digitalWrite(previousAddress, LOW);
  digitalWrite(address, HIGH);
  previousAddress = address;
  
  // write the color
  analogWrite(RED, map(color.red, 0, 255, 0, brightness));
  analogWrite(GREEN, map(color.green, 0, 255, 0, brightness));
  analogWrite(BLUE, map(color.blue, 0, 255, 0, brightness));
}

/**
* Reads 1 byte each time (if available) and appends to buffer.
* If MESSAGE_START is received it resets bytesRead to 0
* If COLOR_MESSAGE_END or INTERVAL_MESSAGE_END are recieved 
* the appropriate message handler function is called.
* If the buffer is full then read bytes are ignored.
**/
void readFromStream () {
  if (!Serial.available()) {
    return;
  }
  
  byte readByte = Serial.read();
  switch (readByte) {
    case MESSAGE_START:
      bytesRead = 0;
      break;
    case COLOR_MESSAGE_END:
      onColorMessage();
      break;
    case INTERVAL_MESSAGE_END:
      onIntervalMessage();
    default:
      if (bytesRead < BUFFER_SIZE) {
        buffer[bytesRead++] = readByte;
      }
  }
}

/**
* Handles a color change message.
* Resets fadeStartTime, sets currentColor = nextColor
* and populates nextColor with the color read from the serial interface.
**/
void onColorMessage () {
  if (bytesRead != COLOR_MESSAGE_LENGTH) {
    return;
  }
  
  fadeStartTime = millis();
  currentColor = nextColor;
  nextColor.red = map(buffer[COLOR_INDEX_RED], 0, 127, 0, 255);
  nextColor.green = map(buffer[COLOR_INDEX_GREEN], 0, 127, 0, 255);
  nextColor.blue = map(buffer[COLOR_INDEX_BLUE], 0, 127, 0, 255);
}

/**
* Handles a set interval message.
* sets fadeTime with the value read from the serial interface.
**/
void onIntervalMessage () {
  if (bytesRead != INTERVAL_MESSAGE_LENGTH) {
    return;
  }
  fadeTime = buffer[INTERVAL_MSB_INDEX] << 7 | buffer[INTERVAL_LSB_INDEX];
}

/**
* Updates the LED display
* Calculates the current fade position (between currentColor and nextColor)
* Increments displayIndex and writes the color to the display
**/
void updateDisplay () {
  unsigned long currentTime = millis();
  float fadePosition = 0;
  if (currentTime - fadeStartTime >= fadeTime) {
    fadePosition = 1.0;
  } else {
    fadePosition = (float)(currentTime - fadeStartTime) / (float)fadeTime;
  }
  
  displayIndex++;
  if (displayIndex > LED_COUNT) {
    displayIndex = 0;
  }
  
  Color color = crossfade(currentColor, nextColor, fadePosition);
  writeColor(color, 255, displayAddresses[displayIndex]);
}

/**
* Crossfades two colors based on fadePosition.
* fadePosition represents a percentage where:
*   0 = from
*   1 = to
**/
Color crossfade(Color from, Color to, float fadePosition) {
  if (fadePosition <= 0) {
    return from;
  } else if (fadePosition >= 1.0) {
    return to;
  }
  
  Color newColor;
  newColor.red = (from.red + round(fadePosition * (to.red - from.red)));
  newColor.green = (from.green + round(fadePosition * (to.green - from.green)));
  newColor.blue = (from.blue + round(fadePosition * (to.blue - from.blue)));
  return newColor;
}

void loop () {
  while (true) {
    readFromStream();
    updateDisplay();
  }
}
