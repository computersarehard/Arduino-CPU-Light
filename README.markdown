# CPU Light

A simple Arduino + Python project that produces an RGB LED light that changes color as CPU usage changes.

## Requirements

1. Python (tested with 2.7.1)
2. [pyserial][1] module
3. [psutil][2] module
4. [Arduino][3]

## Install Required Tools

1. Download the Arduino IDE from [http://arduino.cc][3]
2. Install [pyserial][1]

        $ easy_install pyserial

3. Install [psutil][2]

        $ easy_install psutil

## Setup and Execution

1. Open `arduino/cpu_light/cpu_light.pde` and upload the code to your Arduino
2. Determine the USB device that the Arduino is connected as

    This can be found in the Arduino application itself under Tools > Serial Port

3. Execute the python script:

        $ ./service.py /dev/tty.usbmodem1d11

    Replace `/dev/tty.usbmodem1d11` with the name of the device on your system (Step 2)

[1]: http://pyserial.sourceforge.net/
[2]: http://code.google.com/p/psutil/
[3]: http://arduino.cc
