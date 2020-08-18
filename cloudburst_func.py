import subprocess
import os
import time
import argparse


local = False
AWS_FUNCTION_ELB = 'a591fc1389d974046a76910d7644370e-176098095.us-east-1.elb.amazonaws.com'
MY_IP = 'ec2-54-210-86-239'#'18.209.27.93'

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
    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_client.rb", user_lib.get('client_ip') + ":12347", user_lib.get('proposer_ip') + ":12345"])
    return 100

def proposer(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('proposer_ip', ip)
    print("INSIDE PROPOSER", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)

    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_proposer.rb", "0", user_lib.get('proposer_ip') + ":12345", user_lib.get('acceptor_ip') + ":12346"])
    return 100

def acceptor_1(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    return 100

def acceptor_2(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    return 100

def acceptor_3(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", ip + ":1234" + str(a), user_lib.get('proposer_ip') + ":12345"])
    return 100

parser = argparse.ArgumentParser(description='Set nums of each.')
parser.add_argument("c", help="number of proposers to use", type=int)
parser.add_argument("p", help="number of proposers to use", type=int)
parser.add_argument("a", help="number of proposers to use", type=int)

args = parser.parse_args()

cloud_client = cloudburst.register(client, 'client')
cloud_proposer = cloudburst.register(proposer, 'proposer')

for i in range(args.a):
    cloud_acceptor_1 = cloudburst.register(acceptor_1, 'acceptor-1')
    cloud_acceptor_2 = cloudburst.register(acceptor_2, 'acceptor-2')
    cloud_acceptor_3 = cloudburst.register(acceptor_3, 'acceptor-3')

print("REGISTERED FUNCTIONS")

cloudburst.register_dag('dag', ['client'], [])
print("Registered first dag")
print(cloudburst.call_dag('dag', { 'client': [2] }, direct_response=False))

cloudburst.register_dag('dag2', ['proposer'], [])
print("Registered second dag")
print(cloudburst.call_dag('dag2', { 'proposer': [2] }, direct_response=False))

cloudburst.register_dag('dag3', ['acceptor-1'], [])
print("Registered third dag")
print(cloudburst.call_dag('dag3', { 'acceptor-1': [1] }, direct_response=False))

cloudburst.register_dag('dag4', ['acceptor-2'], [])
print("Registered fourth dag")
print(cloudburst.call_dag('dag4', { 'acceptor-2': [2] }, direct_response=False))

cloudburst.register_dag('dag5', ['acceptor-3'], [])
print("Registered fifth dag")
print(cloudburst.call_dag('dag5', { 'acceptor-3': [3] }, direct_response=False))