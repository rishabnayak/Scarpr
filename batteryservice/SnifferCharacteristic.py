from pybleno import *
import array
import sys
import subprocess
import re

class SnifferCharacteristic(Characteristic):
    def __init__(self):
        Characteristic.__init__(self, {
            'uuid': '0x2A3D',
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
        if sys.platform == 'darwin':
        	output = subprocess.check_output("pmset -g batt", shell=True)
        	for row in output.split('\n'):
        		if 'InternalBatter' in row:
        			percent = row.split('\t')[1].split(';')[0]
        			percent = int(re.findall('\d+', percent)[0])
        			callback(Characteristic.RESULT_SUCCESS, array.array('B', [percent]))
        			break
        else:
            # return hardcoded value
            callback(Characteristic.RESULT_SUCCESS, array.array('B', [98]))

            # write to characteristic repeatedly, use cyble instead of nRFConnect. Set characteristic to be notifiable
            # alternative would be gattpython
