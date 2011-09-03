#!/usr/bin/python

import psutil
import sys
import serial
import time

SEND_INTERVAL_AFTER = 10

MESSAGE_START = 0xFF
COLOR_MESSAGE_END = 0xF0
INTERVAL_MESSAGE_END = 0xF1

class CPUMonitor:
  def __init__(self, port):
    self.interval = 1
    self.output = serial.Serial(port, 9600, timeout=1)
    self.gradient = Gradient([
      Stop(0, (0, 127, 0)),
      Stop(50, (127, 127, 0)),
      Stop(100, (127, 0, 0))
    ])

  def run(self):
    time.sleep(5)
    self.writeinterval()
    count = 0
    while True:
      self.writecolor()
      # Send the interval every so often
      count = count + 1
      if count >= SEND_INTERVAL_AFTER:
        self.writeinterval()
        count = 0

  def writecolor(self):
    # percentage is 0-100
    percentage = psutil.cpu_percent(self.interval, percpu=False)
    color = self.gradient.coloratpercentage(percentage)
    self.output.write(bytearray([MESSAGE_START, color[0], color[1], color[2], COLOR_MESSAGE_END]))

  def writeinterval(self):
    intervalmillis = int(1000 * self.interval)
    msb = (intervalmillis & (0x7F << 7)) >> 7
    lsb = (intervalmillis & 0x7F)
    self.output.write(bytearray([MESSAGE_START, msb, lsb, INTERVAL_MESSAGE_END]))

class Gradient:
  """
    Gradient represents a linear gradient with a set of stops at 
    percentages between 0 and 100.
    This class provides methods to calculate colors at any point
    in the gradient
  """
  def __init__(self, stops):
    self.stops = stops

  def coloratpercentage(self, pct):
    """
      Finds the color in the gradient at pct.
      pct should be between 0 and 100
    """
    if pct >= 100:
      return self.stops[-1].color
    elif pct <= 0:
      return self.stops[0].color

    bounds = self.stopbounds(pct)
    if len(bounds) == 1:
      return bounds[0].color
    return self.colorbetweenstops(pct, bounds)

  def colorbetweenstops(self, pct, stops):
    """
      Calculates the color at pct between the two stop bounds in stops
    """
    lower, upper = stops
    pctbetween = (pct - lower.pct) / (upper.pct - lower.pct)
    # Convert each color component
    return tuple(map(lambda x: int(round(x[0] + pctbetween * (x[1] - x[0]))), zip(lower.color, upper.color)))

  def stopbounds(self, pct):
    """
      Finds the stops two stops are the closest to pct.
      If pct is exact with a stop a tuple with a single value is returned.
      Otherwise, the closest stop below and the closest stop above are returned.

      It is assumed that stops are sorted ascending by pct
    """
    # Find the first stop that is over pct. That is our upper bound
    upperstopindex = 0
    for i in range(0, len(self.stops)):
      if self.stops[i].pct >= pct:
        upperstopindex = i
        break

    if upperstopindex == 0:
      return (self.stops[0],)
    # an exact match
    if self.stops[upperstopindex].pct == pct:
      return (self.stops[upperstopindex],)

    return (self.stops[upperstopindex - 1], self.stops[upperstopindex])

class Stop:
  """
    Represents a color stop in a gradient.
    A color stop is a point in the gradient, specified
    by a percentage (between 0 and 100) that sets a color.
  """
  def __init__(self, pct, color):
    self.pct = pct;
    self.color = color

def usage():
  print >> sys.stderr, "Usage: service.py <usb device>"

if __name__ == '__main__':
  if len(sys.argv) != 2:
    usage()
    sys.exit(1)
  try:
    print "Press CTRL-c to stop."
    while True:
      # Keep trying until we get a connection or interrupt
      try:
        monitor = CPUMonitor(sys.argv[1])
        monitor.run()
      except serial.serialutil.SerialException as e:
        print >> sys.stderr, "IO Error: %s" % e.message
        time.sleep(5)
  except KeyboardInterrupt:
    sys.exit(0)
