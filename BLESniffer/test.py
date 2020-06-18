import subprocess

command = ['python3', './sniffer.py',
           '-a', 'wlan1',
           '-r', '5']
runSniffer = subprocess.Popen(
    command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
output, _ = runSniffer.communicate()
print(output)
