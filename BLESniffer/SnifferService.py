from pybleno import *
from SnifferCharacteristic import *

class SnifferService(BlenoPrimaryService):
    def __init__(self):
        BlenoPrimaryService.__init__(self, {
          'uuid': '181A',
          'characteristics': [
              SnifferCharacteristic()
          ]})