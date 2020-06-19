from pybleno import *
import array
import sys
import subprocess
import re


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
        # self._updateValueCallback(array.array(
        #     'B', [82, 105, 115, 104, 97, 98]))
        # for i in range(5):
        #     self._updateValueCallback(array.array(
        #         'B', [i+80]))
        command = ['python3', './sniffer.py',
                   '-a', 'wlan1',
                   '-r', '5']
        runSniffer = subprocess.Popen(command)
        runSniffer.communicate()
        a = open("./temp.txt", "r")
        b = a.read()
        a.close()
        b = b.split(",")
        b = [abs(int(i)) for i in b]
        self._updateValueCallback(array.array(
                        'B', b))

    def onUnsubscribe(self):
        print('SnifferCharacteristic - onUnsubscribe')
        self._updateValueCallback = None

    def onNotify(self):
        print('SnifferCharacteristic - onNotify')

    # write to characteristic repeatedly, use cyble instead of nRFConnect. Set characteristic to be notifiable
    # alternative would be gattpython
