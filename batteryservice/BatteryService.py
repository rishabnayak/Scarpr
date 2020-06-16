from pybleno import *
from BatteryLevelCharacteristic import *

class BatteryService(BlenoPrimaryService):
    def __init__(self):
        BlenoPrimaryService.__init__(self, {
          'uuid': '181A',
          'characteristics': [
              BatteryLevelCharacteristic()
          ]})