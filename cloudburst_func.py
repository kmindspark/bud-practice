import subprocess
import os
import time
import argparse


local = False
AWS_FUNCTION_ELB = 'a0528f3739efd425d8b6f014a2cd5000-1401044895.us-east-1.elb.amazonaws.com'
MY_IP = 'ec2-3-85-16-70' #'18.209.27.93'

from cloudburst.client.client import CloudburstConnection
cloudburst = CloudburstConnection(AWS_FUNCTION_ELB, MY_IP, local=local)
print("Made it past initialization")

def client(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('client_ip', ip)
    print("INSIDE CLIENT", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(10)
    p = subprocess.Popen(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_client.rb", user_lib.get('client_ip') + ":1235" + str(a), user_lib.get('proposer_ip') + ":12345"])
    time.sleep(40)
    subprocess.call(['kill -9 ' + str(p.pid)], shell=True)
    return 100

def proposer(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('proposer_ip', ip)
    print("INSIDE PROPOSER", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)

    p = subprocess.Popen(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_proposer.rb", "0", user_lib.get('proposer_ip') + ":12345", user_lib.get('acceptor_ip') + ":12346"])
    time.sleep(40)
    subprocess.call(['kill -9 ' + str(p.pid)], shell=True)
    return 100

def acceptor_1(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    p = subprocess.Popen(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    time.sleep(40)
    subprocess.call(['kill -9 ' + str(p.pid)], shell=True)
    return 100

def acceptor_2(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    p = subprocess.Popen(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    time.sleep(40)
    subprocess.call(['kill -9 ' + str(p.pid)], shell=True)
    return 100

def acceptor_3(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    p = subprocess.Popen(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    time.sleep(40)
    subprocess.call(['kill -9 ' + str(p.pid)], shell=True)
    return 100

parser = argparse.ArgumentParser(description='Set nums of each.')
parser.add_argument("c", help="number of proposers to use", type=int)
parser.add_argument("p", help="number of proposers to use", type=int)
parser.add_argument("a", help="number of proposers to use", type=int)

args = parser.parse_args()

for i in range(args.c):
    cloudburst.register(client, 'client-' + str(i))
cloud_proposer = cloudburst.register(proposer, 'proposer')
for i in range(args.a):
    cloudburst.register(acceptor_1, 'acceptor-' + str(i))

for i in range(args.c):
    name = 'client-' + str(i)
    print(name)
    cloudburst.register_dag('dag-' + name, [name], [])
    print("Registered client dag: ", i)
    print(cloudburst.call_dag('dag-' + name, { name: [i] }, direct_response=False))

cloudburst.register_dag('dag2', ['proposer'], [])
print("Registered second dag")
print(cloudburst.call_dag('dag2', { 'proposer': [2] }, direct_response=False))

for i in range(args.a):
    name = 'acceptor-' + str(i)
    print(name)
    cloudburst.register_dag('dag-' + name, [name], [])
    print("Registered acceptor dag: ", i)
    print(cloudburst.call_dag('dag-' + name, { name: [i] }, direct_response=False))