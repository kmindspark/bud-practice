import subprocess
import os
import time
import argparse


local = False
AWS_FUNCTION_ELB = 'a761b9343137342de987258bdcdda6df-671553808.us-east-1.elb.amazonaws.com'
MY_IP = 'ec2-54-146-61-171'#'18.209.27.93'

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

    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_proposer.rb", 0, user_lib.get('proposer_ip') + ":12345", user_lib.get('acceptor_ip') + ":12346"])
    return 100

def acceptor(user_lib, a):
    ip = str(os.popen("ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2").read())[:-1]
    user_lib.put('acceptor_ip', ip)
    print("INSIDE ACCEPTOR", ip)
    while (not (user_lib.get('proposer_ip') and user_lib.get('client_ip') and user_lib.get('acceptor_ip'))):
        time.sleep(1)
    time.sleep(5)
    subprocess.call(["ruby", "/bud-practice/examples/multipaxos_cloudburst/paxos_acceptor.rb", user_lib.get('acceptor_ip') + ":12346", user_lib.get('proposer_ip') + ":12345"])
    return 100

parser = argparse.ArgumentParser(description='Set nums of each.')
parser.add_argument("c", help="number of proposers to use",
                    type=int)
parser.add_argument("p", help="number of proposers to use",
                    type=int)
parser.add_argument("a", help="number of proposers to use",
                    type=int)

args = parser.parse_args()


cloud_client = cloudburst.register(client, 'client')
cloud_proposer = cloudburst.register(proposer, 'proposer')
cloud_acceptor = cloudburst.register(acceptor, 'acceptor')
print("REGISTERED FUNCTIONS")

cloudburst.register_dag('dag', ['client'], [])
print("Registered first dag")
print(cloudburst.call_dag('dag', { 'client': [2] }, direct_response=False))

cloudburst.register_dag('dag2', ['proposer'], [])
print("Registered second dag")
print(cloudburst.call_dag('dag2', { 'proposer': [2] }, direct_response=False))

cloudburst.register_dag('dag3', ['acceptor'], [])
print("Registered third dag")
print(cloudburst.call_dag('dag3', { 'acceptor': [2] }, direct_response=False))