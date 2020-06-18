from pybleno import *
import array
import sys
import subprocess
import re


class SnifferCharacteristic(Characteristic):
    def __init__(self):
        Characteristic.__init__(self, {
            'uuid': '2A3D',
            'properties': ['read', 'notify'],
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

    def onReadRequest(self, offset, callback):
        print('SnifferCharacteristic - %s - onReadRequest: value = %s' %
              (self['uuid'], [hex(c) for c in self._value]))
        callback(Characteristic.RESULT_SUCCESS, self._value[offset:])

    def onSubscribe(self, maxValueSize, updateValueCallback):
        print('SnifferCharacteristic - onSubscribe')
        self._updateValueCallback = updateValueCallback
        self._updateValueCallback(array.array(
            'B', [82, 105, 115, 104, 97, 98]))
        command = ['python3', './sniffer.py',
                   '-a', 'wlan1',
                   '-r', '5']
        runSniffer = subprocess.Popen(command)
        output, _ = runSniffer.communicate()
        print(output)

    def onUnsubscribe(self):
        print('SnifferCharacteristic - onUnsubscribe')
        self._updateValueCallback = None

    def onNotify(self):
        print('SnifferCharacteristic - onNotify')

    # write to characteristic repeatedly, use cyble instead of nRFConnect. Set characteristic to be notifiable
    # alternative would be gattpython
