import threading
import sys
import os
import os.path
import subprocess
import json
import time

import statistics
import netifaces
import click

from pick import pick
import curses


def which(program):
    """Determines whether program exists
    """
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, _ = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file
    sys.exit(1)

def load_dictionary(file):
    oui = {}
    with open(file, 'r') as f:
        for line in f:
            if '(hex)' in line:
                data = line.split('(hex)')
                key = data[0].replace('-', ':').lower().strip()
                company = data[1].strip()
                oui[key] = company
    return oui

@click.command()
@click.option('-a', '--adapter', default='', help='adapter to use')
@click.option('-r', '--refreshrate', default='60', help='refresh rate')
@click.option('-d', '--dictionary', default='oui.txt', help='OUI dictionary')
@click.option('-c', '--deltarssi', default=0, help='set change in RSSI to account for')
def main(adapter, refreshrate, dictionary, deltarssi):
    foundMacs = {}
    while True:
        adapter = scan(adapter, refreshrate, dictionary, deltarssi, foundMacs)

def scan(adapter, refreshrate, dictionary, deltarssi, foundMacs):

    if (not os.path.isfile(dictionary)) or (not os.access(dictionary, os.R_OK)):
        print(
            'couldn\'t load [%s], please download from http://standards-oui.ieee.org/oui/oui.txt' % dictionary)
        sys.exit(1)

    oui = load_dictionary(dictionary)

    try:
        tshark = which("tshark")
    except:
        print('tshark not found, install before runnning this script')
        sys.exit(1)

    if len(adapter) == 0:
        if os.name == 'nt':
            print('You must specify the adapter with   -a ADAPTER')
            print('Choose from the following: ' +
                  ', '.join(netifaces.interfaces()))
            sys.exit(1)
        title = 'Please choose the adapter you want to use: '
        try:
            adapter, _ = pick(netifaces.interfaces(), title)
        except curses.error as e:
            print('Please check your $TERM settings: %s' % (e))
            sys.exit(1)

    command = ['sudo', tshark, '-I', '-i', adapter,
               '-a', 'duration:' + refreshrate,
               '-Y', 'wlan.fc.type_subtype eq 4',
               '-T', 'fields', '-e',
               'wlan.sa', '-e',
               'wlan.bssid_resolved', '-e',
               'radiotap.dbm_antsignal', '-e',
               'radiotap.txpower']

    run_tshark = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output, _ = run_tshark.communicate()

    deviceList = [
        'Motorola Mobility LLC, a Lenovo Company',
        'GUANGDONG OPPO MOBILE TELECOMMUNICATIONS CORP.,LTD',
        'Huawei Symantec Technologies Co.,Ltd.',
        'Microsoft',
        'HTC Corporation',
        'Samsung Electronics Co.,Ltd',
        'SAMSUNG ELECTRO-MECHANICS(THAILAND)',
        'BlackBerry RTS',
        'LG ELECTRONICS INC',
        'Apple, Inc.',
        'LG Electronics',
        'OnePlus Tech (Shenzhen) Ltd',
        'Xiaomi Communications Co Ltd',
        'LG Electronics (Mobile Communications)']
    # ctr = 0
    for line in output.decode('utf-8').split('\n'):
        print(line)
        if line.strip() == '':
            continue
        mac = line.split()[0].strip().split(',')[0]
        dats = line.split()
        if len(dats) == 3:
            if ':' not in dats[0] or len(dats) != 3:
                continue
            rssi = dats[2]
            if mac not in foundMacs:
                # foundMacs[mac] = [ctr, float(rssi)]
                foundMacs[mac] = [float(rssi)]
                oui_id = 'Not in OUI'
                if mac[:8] in oui:
                    oui_id = oui[mac[:8]]
                if oui_id in deviceList:
                    print({'RSSI': rssi, 'MAC Address': mac})
                    a = os.open('temp.txt', os.O_WRONLY)
                    # os.write(a, str(ctr).encode())
                    os.write(a, str(mac).encode())
                    os.write(a, ",".encode())
                    os.write(a, str(rssi).encode())
                # ctr += 1
                continue
            foundMacs[mac].append(float(rssi))

    for mac in foundMacs:
        oui_id = 'Not in OUI'
        if mac[:8] in oui:
            oui_id = oui[mac[:8]]
        if oui_id in deviceList:
            # if len(foundMacs[mac][1:]) >= 2:
            if len(foundMacs[mac]) >= 2:
                # if round(statistics.stdev(foundMacs[mac][1:])) >= deltarssi:
                if round(statistics.stdev(foundMacs[mac])) >= deltarssi:
                    print("Location Changed! Standard Deviation of RSSI for", mac, "=",
                        #   round(statistics.stdev(foundMacs[mac][1:])))
                        round(statistics.stdev(foundMacs[mac])))
                    print("New Data:", {'RSSI': float(
                        # round(statistics.mean(foundMacs[mac][1:]), 2)), 'MAC Address': mac})
                        round(statistics.mean(foundMacs[mac]), 2)), 'MAC Address': mac})
                    a = os.open('temp.txt', os.O_WRONLY)
                    os.write(a, str(mac).encode())
                    os.write(a, ",".encode())
                    os.write(a, str(float(round(statistics.mean(foundMacs[mac]), 2))).encode())
        # foundMacs[mac] = [foundMacs[mac][0]]+[float(round(statistics.mean(foundMacs[mac][1:]), 2))]
        foundMacs[mac] = [float(round(statistics.mean(foundMacs[mac]), 2))]

    return adapter


if __name__ == '__main__':
    main()
