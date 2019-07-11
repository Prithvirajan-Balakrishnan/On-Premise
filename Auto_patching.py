import json
import sys
import time
import subprocess
import os
import urllib2

try:
    import requests
except ImportError:
    print "Please install the python-requests module."
    sys.exit(-1)

from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

SAT_API = 'https://satserver.domain.com/'

USERNAME = "admin"
p = subprocess.Popen(['/usr/local/bin/ftppwd', 'satserver', USERNAME], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out, err=p.communicate()
PASSWORD=out.rstrip()

SSL_VERIFY = False   # Ignore SSL for now

def get_json(url):
    # Performs a GET using the passed URL location
    r = requests.get(url, auth=(USERNAME, PASSWORD), verify=SSL_VERIFY)
    return r.json()

def get_results(url):
    jsn = get_json(url)
    if jsn.get('error'):
        print "Error: " + jsn['error']['message']
    else:
        if jsn.get('results'):
            return jsn['results']
        elif 'results' not in jsn:
            return jsn
        else:
            print "No results found"
    return None

def post_json(location):
    """
    Performs a POST and passes the data to the URL location
    """
    POST_HEADERS = {'content-type': 'application/json'}
    result = requests.put(
        location,
        auth=(USERNAME, PASSWORD),
        verify=SSL_VERIFY,
        headers=POST_HEADERS)

    return result.json()

def post_new_json(location, json_data):
    POST_HEADERS = {'content-type': 'application/json'}
    result = requests.post(
        location,
        data=json_data,
        auth=(USERNAME, PASSWORD),
        verify=SSL_VERIFY,
        headers=POST_HEADERS)

    return result.json()

def wait_for_upgrade_job(seconds,EnvG):
    nodes=[]
    uniqueNodes = []
    #upgrade_tasks = "foreman_tasks/api/tasks?search=utf8=%E2%9C%93&search=label+%3D+Actions%3A%3AKatello%3A%3AHost%3A%3APackage%3A%3AUpdate+and+state+%3D+running"
    upgrade_tasks = "foreman_tasks/api/tasks?utf8=.&search=label+%3D+Actions%3A%3AKatello%3A%3AHost%3A%3APackage%3A%3AUpdate+and+state+%3D+running"
    """
    Wait for all package upgrade tasks to terminate. Search string is:
    label = Actions::Katello::Host::Package::Update and state = running
    """

    count = 0
    print "Waiting for package upgrade tasks to finish..."

    # Make sure that package upgrade tasks gets the chance to appear before looking for them
    time.sleep(2)

    while get_json(SAT_API + upgrade_tasks)["total"] != 0:
        time.sleep(seconds)
        count += 1
        notifier = seconds * count / 60
        if notifier%10 == 0 and count%600 == 0:
                TaskList = get_json(SAT_API + upgrade_tasks)
                length=len(TaskList['results'])
                for i in range(0,length):
                        y = TaskList['results'][i]['input']['host']['name']
                        nodes.append(str(y))

                for elem in nodes:
                        if elem not in uniqueNodes:
                            uniqueNodes.append(elem)

                cmd='/usr/bin/curl -X POST --data-urlencode \'payload={\"channel\": \"#uketsunix\", \"username\": \"PA Admin\", \"text\": \"`%s patching running for more than %i minutes. Please check the servers %s. Initiating Autohealing ... `\"}\' https://hooks.slack.com/services/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 --proxy \"https://192.22.65.60:9099\"'% (EnvG, notifier, uniqueNodes)
                os.system(cmd)
                print "Initiating AutoHealing Process . . . "
                NodeCount=len(uniqueNodes)
                for x in range(len(uniqueNodes)):
                        job_id = post_new_json(
                            SAT_API + "/api/job_invocations/",
                            json.dumps(
                                        {"job_invocation":{"job_template_id": "107", "targeting_type": "static_query", "inputs": {"command": "dzdo /sbin/service goferd restart"}, "search_query": "name = %s" % str(uniqueNodes[x])}}
                ))
                print uniqueNodes[x]
                print uniqueNodes
                notifier = 0
    print "Finished waiting after " + str(seconds * count) + " seconds"

#               os.system("/usr/bin/curl -vv -X PUT -H "Accept:application/json,version=2"  -H "Content-Type:application/json" -u admin:Capital1 -d "{\"organization_id\":3,   \"included\":{\"search\":\" host_collection  =  RHEL-6-DEV-Hostgrp\"}, \"content_type\":\"package\", \"content\":[\"capitalone-CVusercreation*\"]}" https://satserver.domain.com//api/v2/hosts/bulk/install_content")

#               os.system("/usr/bin/curl -vv -X PUT -H "Accept:application/json,version=2"  -H "Content-Type:application/json" -u admin:Capital1 -d "{\"organization_id\":3,   \"included\":{\"search\":\" host_collection  =  RHEL-6-DEV-Hostgrp-Manual\"}, \"content_type\":\"package\", \"content\":[\"capitalone-CVusercreation*\"]}" https://satserver.domain.com//api/v2/hosts/bulk/install_content")

#time.sleep(600)


def display_task_results(url,reportdir):
    results = get_results(url)
    if results:
        UpgrdPkgList=results['humanized']['output']
        HostName=results['input']['host']['name']
        file=reportdir.__add__(HostName).__add__("-UpPkgs")
        uppkg_file=open(file,"wb")
        uppkg_file.write(UpgrdPkgList);
        uppkg_file.close

def patch_host_collection(url,reportdir,env):
    results = get_results(url)
    EnvG=env
    if results:
        length=len(results['host_ids'])
        data = [{'NodeId' : 'hid', 'JobId' : 'job_id'} for k in range(length)]
        for i in range(0,length):
                hid = results['host_ids'][i]
                location=SAT_API + 'api/hosts/%d/packages/upgrade_all' % hid
                out=post_json(location)
                data[i]['JobId']=out['id']
                data[i]['NodeId']=hid
        wait_for_upgrade_job(1,EnvG)
        for k in range(0,length):
                display_task_results(SAT_API + '/foreman_tasks/api/tasks/%s' % data[k]['JobId'], reportdir)


def main():
    #Supplied argument validation and decoding
    arg_count=len(sys.argv)
    if ( arg_count<=1 ):
        print "Usage : ./script.py SystemGroup"
        exit(1)

#   SysGroup = {'RHEL-5-SIT': 4, 'RHEL-6-SIT': 10}
#   SysGroup = {'RHEL-5-DEV': 1, 'RHEL-6-DEV': 7}
    SysGroup = {'RHEL-5-DEV': 1, 'RHEL-6-DEV': 7, 'RHEL-7-DEV': 13, 'RHEL-5-SIT': 4, 'RHEL-6-SIT': 10, 'RHEL-6-TEST': 19}
    HostGroup=SysGroup[str(sys.argv[1])]
    print HostGroup
    env=str(sys.argv[1])
    print env
    date=(time.strftime("%Y-%m-%d"))

    #Defining report directory and file
    reportdir=("/PatchAutomation/Reports/%s/" % env).__add__(date).__add__('-reports/')
    print reportdir
    file_path=reportdir.__add__("file")
    print file_path
    directory=os.path.dirname(file_path)
    if not os.path.exists(directory):
        os.makedirs(directory)

    POST_HEADERS = {'content-type': 'application/json'}
    patch_host_collection(SAT_API + 'katello/api/host_collections/%s' % HostGroup, reportdir, env)

    cmd='/usr/bin/curl -X POST --data-urlencode \'payload={\"channel\": \"#uketsunix\", \"username\": \"PA Admin\", \"text\": \"```%s Patching have successfully completed.```\"}\' https://hooks.slack.com/services/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 --proxy \"https://192.22.65.60:9099\"'% env

    os.system(cmd)

if __name__ == "__main__":
    main()

