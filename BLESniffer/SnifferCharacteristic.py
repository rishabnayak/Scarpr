from pybleno import *
import array
import sys
import subprocess
import re
import time

class SnifferCharacteristic(Characteristic):
    def __init__(self):
        Characteristic.__init__(self, {
            'uuid': '2A3D',
            'properties': ['notify'],
            'value': None,
            'descriptors': [
                Descriptor({
                    'uuid': '2901',
                    'value': 'JSON containing RSSI and MAC Address of Devices'
                })
            ]
        })

        self._value = array.array('B', [0] * 0)
        self._updateValueCallback = None

    def onSubscribe(self, maxValueSize, updateValueCallback):
        print('SnifferCharacteristic - onSubscribe')
        self._updateValueCallback = updateValueCallback
        while True:
            a = open("./temp.txt", "r")
            b = a.read()
            b = [ord(c) for c in b]
            self._updateValueCallback(array.array(
                'B', b))
            time.sleep(5)

    def onUnsubscribe(self):
        print('SnifferCharacteristic - onUnsubscribe')
        self._updateValueCallback = None

    def onNotify(self):
        print('SnifferCharacteristic - onNotify')
